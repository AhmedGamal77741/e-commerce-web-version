String getFriendlyAuthError(String code) {
  switch (code) {
    case 'invalid-credential':
      return "잘못된 이메일 또는 비밀번호.";
    case 'invalid-email':
      return '올바른 이메일 주소를 입력해주세요.';
    case 'user-not-found':
      return '이 이메일로 가입된 계정이 없습니다.';
    case 'user-disabled':
      return '이 계정은 비활성화되었습니다.';
    case 'wrong-password':
      return '비밀번호가 틀립니다. 다시 시도해주세요.';
    case 'email-already-in-use':
      return '이미 이 이메일로 가입된 계정이 있습니다.';
    case 'weak-password':
      return '비밀번호가 너무 약합니다. 6자 이상 사용해주세요.';
    case 'too-many-requests':
      return '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
    case 'operation-not-allowed':
      return '이메일/비밀번호 로그인 기능이 활성화되지 않았습니다.';
    default:
      return '잘못된 이메일 또는 비밀번호.';
  }
}
