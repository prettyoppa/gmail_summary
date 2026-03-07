class UserModel {
  String name;
  String birthday;
  String gender;
  String country;

  String englishName;
  String nickname;
  String address;

  String? naverId;
  String? naverPw;
  String? daumId;
  String? daumPw;

  UserModel({
    this.name = '',
    this.birthday = '',
    this.gender = '',
    this.country = '',
    this.englishName = '',
    this.nickname = '',
    this.address = '',
    this.naverId,
    this.naverPw,
    this.daumId,
    this.daumPw,
  });

  factory UserModel.empty() => UserModel();

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      name: map['name'] ?? '',
      birthday: map['birthday'] ?? '',
      gender: map['gender'] ?? '남성',
      country: map['country'] ?? '대한민국',
      englishName: map['englishName'] ?? '',
      nickname: map['nickname'] ?? '',
      address: map['address'] ?? '',
      // 💡 [추가] DB에서 가져올 때 매핑
      naverId: map['naver_id'],
      naverPw: map['naver_pw'],
      daumId: map['daum_id'],
      daumPw: map['daum_pw'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'englishName': englishName,
      'nickname': nickname,
      'gender': gender,
      'birthday': birthday,
      'country': country,
      'address': address,
      // 💡 [추가] DB에 저장할 때 매핑
      'naver_id': naverId,
      'naver_pw': naverPw,
      'daum_id': daumId,
      'daum_pw': daumPw,
    };
  }
}
