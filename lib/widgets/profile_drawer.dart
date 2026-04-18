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
  final Function(UserModel) onSave;
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

class _ProfileDrawerState extends State<ProfileDrawer> {
  late TextEditingController _nameController;
  late TextEditingController _countryController;
  late TextEditingController _enNameController;
  late TextEditingController _nickController;
  late TextEditingController _addressController;
  late String _selectedGender;
  late String _birthday;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _countryController = TextEditingController(text: widget.user.country);
    _enNameController = TextEditingController(text: widget.user.englishName);
    _nickController = TextEditingController(text: widget.user.nickname);
    _addressController = TextEditingController(text: widget.user.address);

    // ✅ 성별 기본값 설정: 비어있으면 '공개안함'
    _selectedGender = (widget.user.gender.isEmpty || widget.user.gender == "")
        ? "공개안함"
        : widget.user.gender;
    _birthday = widget.user.birthday;
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
                    widget.onLogout!();
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.pop(context);
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
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Drawer(
      width: isMobile ? screenWidth : 400,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black, size: 32),
              onPressed: () => Scaffold.of(context).closeEndDrawer(),
              padding: const EdgeInsets.only(right: 20, top: 10),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 로그아웃 섹션
              InkWell(
                onTap: () => _showLogoutDialog(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100, width: 1.5),
                    boxShadow: [
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
                                  widget.googleSignIn.currentUser?.email ??
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
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
              const SizedBox(height: 20),

              // ✅ 필드 수정: 이름 (필수 제거)
              _buildField(_nameController, "이름"),
              const SizedBox(height: 14),

              // ✅ 필드 수정: 거주국 (필수 제거)
              InkWell(
                onTap: () {
                  showCountryPicker(
                    context: context,
                    favorite: ['KR'],
                    onSelect: (Country country) {
                      setState(() {
                        _countryController.text =
                            country.nameLocalized ?? country.name;
                      });
                    },
                  );
                },
                child: IgnorePointer(
                  child: _buildField(_countryController, "거주국"),
                ),
              ),
              const SizedBox(height: 14),

              // ✅ 필드 수정: 생년월일 (필수 제거 및 에러 로직 삭제)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListTile(
                  title: const Text("생년월일", style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    _birthday.isEmpty || _birthday == "날짜 선택"
                        ? "날짜 선택"
                        : _birthday,
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    DateTime initialDate = DateTime(2000);
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _birthday =
                            "${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}";
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 14),

              // ✅ 성별 선택: 드롭다운 방식으로 변경
              const Text(
                "성별",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: ['공개안함', '남성', '여성'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedGender = newValue!;
                  });
                },
              ),

              const SizedBox(height: 14),
              _buildField(_enNameController, "영문 이름"),
              const SizedBox(height: 14),
              _buildField(_nickController, "닉네임"),
              const SizedBox(height: 14),
              _buildField(_addressController, "주소", maxLines: 2),

              const SizedBox(height: 30),

              // ✅ 설정 저장 버튼: 필수 입력 검증 로직 제거
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    FocusScope.of(context).unfocus();

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

              if (widget.isAdmin) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
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
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200, width: 1),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
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
  }) {
    return TextField(
      controller: controller,
      autofocus: false,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[100],
        border: const OutlineInputBorder(),
      ),
    );
  }
}
