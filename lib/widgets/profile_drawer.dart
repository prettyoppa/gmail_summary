import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:country_picker/country_picker.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gmail_summary/screens/admin_dashboard_screen.dart';
import 'mail_integration_section.dart';

class ProfileDrawer extends StatefulWidget {
  final UserModel user;
  final GoogleSignIn googleSignIn;
  final Function(UserModel) onSave; // onSave 정의를 추가했습니다.
  final VoidCallback? onLogout;
  final bool isAdmin;

  const ProfileDrawer({
    Key? key,
    required this.user,
    required this.googleSignIn,
    required this.onSave,
    required this.isAdmin,
    this.onLogout,
  }) : super(key: key);

  @override
  _ProfileDrawerState createState() => _ProfileDrawerState();
}

bool _nameError = false;
bool _countryError = false;
bool _birthdayError = false;

class _ProfileDrawerState extends State<ProfileDrawer> {
  late TextEditingController _nameController;
  late TextEditingController _countryController;
  late TextEditingController _enNameController;
  late TextEditingController _nickController;
  late TextEditingController _addressController;
  late String _selectedGender;
  late String _birthday;

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // title: const Text("로그아웃"),
          content: const Text("로그아웃 하시겠습니까?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () async {
                try {
                  if (widget.onLogout != null) {
                    widget.onLogout!(); // 로그아웃 콜백 실행
                  }
                  if (mounted) {
                    Navigator.pop(context); // 다이얼로그 닫기
                    Navigator.pop(context); // Drawer 닫기
                    // 메인으로 이동
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                } catch (e) {
                  debugPrint("로그아웃 에러: $e");
                }
              },
              child: const Text("확인", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant ProfileDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // isAdmin 값이 바뀌면 즉시 화면을 다시 그려라!
    if (widget.isAdmin != oldWidget.isAdmin) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    // UserModel에는 name이라는 변수가 있으므로 아래와 같이 수정합니다.
    _nameController = TextEditingController(text: widget.user.name);
    _countryController = TextEditingController(text: widget.user.country);
    _enNameController = TextEditingController(text: widget.user.englishName);
    _nickController = TextEditingController(text: widget.user.nickname);
    _addressController = TextEditingController(text: widget.user.address);
    _selectedGender = widget.user.gender.isEmpty ? "남성" : widget.user.gender;
    _birthday = widget.user.birthday;
  }

  @override
  Widget build(BuildContext context) {
    // 1. 화면 너비를 계산합니다.
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600; // 모바일/웹 판별

    return Drawer(
      // 2. 너비를 모바일일 때는 전체(screenWidth)로 설정합니다.
      width: isMobile ? screenWidth : 400,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black, size: 32),
              onPressed: () {
                Scaffold.of(context).closeEndDrawer();
              },
              padding: const EdgeInsets.only(right: 20, top: 10),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const SizedBox(height: 10),
              InkWell(
                onTap: () => _showLogoutDialog(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ), // 세로 여백 살짝 늘림
                  decoration: BoxDecoration(
                    color: Colors.white, // 배경을 흰색으로 하고
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.shade100,
                      width: 1.5,
                    ), // 테두리 강조
                    boxShadow: [
                      // 버튼처럼 보이게 하는 그림자 효과 추가
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 왼쪽 텍스트 영역
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "로그아웃",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              FirebaseAuth.instance.currentUser?.email ??
                                  "계정 정보 없음",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 오른쪽 로그아웃 아이콘 영역 (버튼임을 명시)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50, // 아이콘 배경에 연한 빨간색
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.logout,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // const Divider(),
              const SizedBox(height: 10),

              _buildField(
                _nameController,
                "이름 *",
                errorText: _nameError ? "이름을 입력해 주세요" : null,
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  showCountryPicker(
                    context: context,
                    showPhoneCode: false,
                    favorite: ['KR'],
                    onSelect: (Country country) {
                      setState(() {
                        _countryController.text =
                            country.nameLocalized ?? country.name;
                      });
                    },
                    countryListTheme: CountryListThemeData(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      inputDecoration: const InputDecoration(
                        hintText: '국가 이름 검색',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  );
                },
                child: IgnorePointer(
                  child: _buildField(
                    _countryController,
                    "거주국 *",
                    errorText: _countryError ? "거주국을 선택해 주세요" : null,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _birthdayError ? Colors.red[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _birthdayError ? Colors.red : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      title: const Text(
                        "생년월일 *",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        _birthday.isEmpty || _birthday == "날짜 선택"
                            ? "날짜 선택"
                            : _birthday,
                      ),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        DateTime initialDate = DateTime(2000);
                        if (_birthday != "날짜 선택" && _birthday.isNotEmpty) {
                          try {
                            List<String> parts = _birthday.split('/');
                            initialDate = DateTime(
                              int.parse(parts[0]),
                              int.parse(parts[1]),
                              int.parse(parts[2]),
                            );
                          } catch (e) {
                            initialDate = DateTime(2000);
                          }
                        }

                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                          initialEntryMode: DatePickerEntryMode.calendarOnly,
                        );

                        if (picked != null) {
                          setState(() {
                            _birthday =
                                "${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}";
                            _birthdayError = false;
                          });
                        }
                      },
                    ),
                  ),
                  if (_birthdayError)
                    const Padding(
                      padding: EdgeInsets.only(left: 12, top: 4),
                      child: Text(
                        "생년월일을 선택해 주세요",
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "성별",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: '남성',
                      label: Text('남성'),
                      icon: Icon(Icons.male),
                    ),
                    ButtonSegment<String>(
                      value: '여성',
                      label: Text('여성'),
                      icon: Icon(Icons.female),
                    ),
                  ],
                  selected: {_selectedGender},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedGender = newSelection.first;
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.blue[100];
                      }
                      return null;
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              _buildField(_enNameController, "영문 이름"),
              const SizedBox(height: 14),
              _buildField(_nickController, "닉네임"),
              const SizedBox(height: 14),
              _buildField(_addressController, "주소", maxLines: 2),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    FocusScope.of(context).unfocus();

                    setState(() {
                      _nameError = _nameController.text.trim().isEmpty;
                      _countryError = _countryController.text.trim().isEmpty;
                      _birthdayError =
                          _birthday.isEmpty || _birthday == "날짜 선택";
                    });

                    if (_nameError || _countryError || _birthdayError) {
                      return;
                    }

                    widget.onSave(
                      UserModel(
                        name: _nameController.text.trim(),
                        country: _countryController.text.trim(),
                        birthday: _birthday.trim(),
                        gender: _selectedGender,
                        englishName: _enNameController.text.trim(),
                        nickname: _nickController.text.trim(),
                        address: _addressController.text.trim(),
                      ),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ 프로필 정보가 저장되었습니다.')),
                    );

                    Navigator.pop(context);
                  },
                  child: const Text("설정 저장"),
                ),
              ),
              const MailIntegrationSection(),
              // ✨ 여기 아래에 관리자 메뉴를 추가합니다.
              if (widget.isAdmin) ...[
                const SizedBox(height: 20), // 설정 저장 버튼과의 간격
                const Divider(),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    // 1. 드로어를 먼저 닫습니다.
                    Navigator.pop(context);

                    debugPrint("관리자 대시보드 진입 시도");

                    // 2. 관리자 대시보드 화면으로 이동합니다.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminDashboardScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 15.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50], // 하단이라서 조금 더 차분한 배경색
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, // 중앙 정렬
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "관리자 전용: 사용자 현황 모니터링",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      autofocus: false, // <-- 자동 포커스를 방지하여 불필요한 입력창 활성화를 막습니다.
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        filled: true,
        fillColor: Colors.grey[100],
        border: const OutlineInputBorder(),
        errorStyle: const TextStyle(color: Colors.red),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}
