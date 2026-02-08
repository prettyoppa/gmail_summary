// lib/models/user_model.dart

class UserModel {
  // 필수 항목
  String name;
  String birthday;
  String gender;
  String country;

  // 선택 항목
  String englishName;
  String nickname;
  String address;

  UserModel({
    this.name = '',
    this.birthday = '',
    this.gender = '',
    this.country = '',
    this.englishName = '',
    this.nickname = '',
    this.address = '',
  });

  factory UserModel.empty() {
    return UserModel(
      name: '',
      birthday: '',
      gender: '',
      country: '',
      englishName: '',
      nickname: '',
      address: '',
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      name: map['name'] ?? '',
      birthday: map['birthday'] ?? '',
      gender: map['gender'] ?? '남성',
      country: map['country'] ?? '대한민국',
      englishName: map['englishName'] ?? '',
      nickname: map['nickname'] ?? '',
      address: map['address'] ?? '',
    );
  }
  // models/user_model.dart 내부 어딘가에 추가
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'englishName': englishName,
      'nickname': nickname,
      'gender': gender,
      'birthday': birthday,
      'country': country,
      'address': address,
    };
  }
}
