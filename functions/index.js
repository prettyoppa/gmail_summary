const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const geminiApiKey = defineSecret("GEMINI_API_KEY");

// 한국 시간 기준 날짜 생성을 위한 헬퍼 함수
const getKSTInfo = () => {
  const now = new Date();
  const kstString = new Intl.DateTimeFormat('ko-KR', {
    timeZone: 'Asia/Seoul',
    dateStyle: 'full',
    timeStyle: 'medium'
  }).format(now);
  const kstDateOnly = new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(now);

  return { kstString, kstDateOnly };
};

exports.getSummary = onRequest({
  secrets: [geminiApiKey],
  cors: true
}, async (req, res) => {
  // 🎯 [로그 1] 함수 진입 확인
  console.log(">>>>>>> [FUNCTION START] getSummary Called <<<<<<<");
  try {
    // 🎯 [로그 2] 들어온 원본 데이터 확인
    console.log(">>>>>>> [INCOMING DATA]:", JSON.stringify(req.body));
    const {
      mailId,
      emailContent,
      userModel = "gemini-2.0-flash", // 사용자님이 설정한 기본 모델
      promptInstruction
    } = req.body;

    if (!emailContent) {
      return res.status(400).send("요약할 내용이 없습니다.");
    }

    const { kstString, kstDateOnly } = getKSTInfo();

    // --- 1. 관리자 프롬프트(Remote Config) 가져오기 ---
    let adminPrompt = "";
    try {
      const config = admin.remoteConfig();
      const template = await config.getTemplate();
      adminPrompt = template.parameters['admin_real_prompt']?.defaultValue?.value || "";
    } catch (configError) {
      console.error("Remote Config 로드 실패:", configError);
    }

    // --- 2. AI 설정 ---
    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({
      model: userModel,
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 8192,
        responseMimeType: "application/json",
      }
    });

    const finalPrompt = `
// # Context
// - Today's Date: ${kstDateOnly}

// # Raw Data (Email Content)
// ${emailContent}

// # Tasks to Perform
// 1. Summary: ${promptInstruction} 
//    - DO NOT add any other summarization rules. Strictly follow the user's customPrompt above.
// 2. Calendar Event Extraction (Conditional): 
//    - Extract only if there are specific dates, times, or clear appointments (meetings, deadlines, etc.).
//    - If no clear event is found or the date is missing, set all "event_info" values to "".
//    - Default Year: 2026 (if year is missing).
//    - Default Time: 09:00:00 (if time is missing).
// 3. Message-ID Task: Look for the "Message-ID" or "Message-Id" field in the email headers within the Raw Data. It is usually enclosed in angle brackets like <...>. Extract the text including the brackets. If not found, return "".

// # Mandatory Constraints
// - Output must be in VALID JSON format ONLY.
// - If no event is detected, provide empty strings ("") for all event_info fields.
// - DO NOT generate a "clean_body" field.

// # Final Output (JSON ONLY)
// {
//   "summary": "Result based strictly on customPrompt",
//   "event_info": [
//   { 
//       "title": "일정 제목", 
//       "start": "YYYY-MM-DDTHH:mm:ss", 
//       "location": "장소 또는 없음"
//   }
//   ],
//   "message_id": "Extracted Message-ID"
// }
# Context
- Current Reference Date (Today): ${kstDateOnly}
- Use the year from the Reference Date above as the default year for events unless specified otherwise.

# Raw Data (Email Content)
${emailContent}

# Tasks
1. Summary: Follow this instruction strictly -> "${promptInstruction}"
2. Calendar Event Extraction: 
   - Extract ALL specific dates and events mentioned in the email.
   - **IMPORTANT: Only extract events that occur on or after Today (${kstDateOnly}). Skip any past events.**
   - If a year is not mentioned in the email, assume it is the year from the Reference Date.
   - If a time is missing, set it to "09:00:00".
   - Return as a LIST of objects. If no future events are found, return [].

# Constraints
- Output must be VALID JSON.
- Standard ISO 8601 format for "start": "YYYY-MM-DDTHH:mm:ss".
- DO NOT include past events relative to ${kstDateOnly}.

# Final Output (JSON ONLY)
{
  "summary": "Summary text here",
  "event_info": [
    {
      "title": "Event Title",
      "start": "YYYY-MM-DDTHH:mm:ss",
      "location": "Location"
    }
  ],
  "message_id": "Extracted Message-ID"
}
`;

    // console.log("--- FINAL PROMPT TO GEMINI ---");
    // // 보안을 위해 프롬프트 로그는 필요할 때만 켭니다.
    // console.log(finalPrompt);

    // --- 4. Gemini 실행 및 결과 처리 ---
    console.log(">>>>>>> [FINAL PROMPT]:", finalPrompt);
    const result = await model.generateContent(finalPrompt);
    let responseText = result.response.text().trim();

    // 🎯 [로그 3] AI의 생답변 확인
    console.log(">>>>>>> [AI RAW RESPONSE]:", responseText);

    // 1. 마크다운 제거
    responseText = responseText.replace(/^```json/, "").replace(/```$/, "").trim();
    console.log("--- [DEBUG] RAW RESPONSE FROM GEMINI ---");
    console.log(responseText);

    try {
      // 2. ⭐ 핵심: 여기서 문자열을 진짜 JSON 객체로 바꿉니다.
      const parsedJson = JSON.parse(responseText);

      console.log("--- [DEBUG] PARSED JSON OBJECT ---");
      console.log("Summary Length:", parsedJson.summary?.length);
      console.log("Event Info Found:", !!(parsedJson.event_info && parsedJson.event_info.title));
      console.log("Clean Body Snippet:", parsedJson.clean_body?.substring(0, 100));

      // 🎯 [로그 4] 최종 전송 데이터 확인
      console.log(">>>>>>> [FINAL JSON TO APP]:", JSON.stringify(parsedJson));
      res.json(parsedJson);

    } catch (e) {
      console.error("JSON 파싱 에러:", e);
      console.error("--- [ERROR] JSON PARSING FAILED ---");
      console.error("Error Message:", e.message);
      console.error("Problematic Text:", responseText);
      // 파싱 실패 시 안전장치 (문자열로라도 보냄)
      res.json({
        status: "error", // 앱에서 감지할 키
        summary: "분석을 완료하지 못했습니다.",
        event_info: null,
        clean_body: responseText
      });
    }

  } catch (error) {
    console.error("서버 최종 오류:", error);
    // 에러 발생 시에도 JSON 형식을 반환하여 앱의 로딩을 멈춰줍니다.
    console.error("--- [CRITICAL ERROR] SERVER FAILED ---");
    console.error(error.stack);
    console.error(">>>>>>> [CRITICAL ERROR]:", error.toString());
    res.status(200).json({
      status: "error",
      summary: "서버 오류가 발생했습니다.",
      guide: "서버 통신 중 예기치 못한 문제가 발생했습니다. 잠시 후 다시 시도해 주시고, 문제가 지속되면 프롬프트를 더 간단하게 수정해 보세요.",
      event_info: null,
      clean_body: error.message
    });
  }
});