class AppConfig {
  // Backend API URL - Live production backend (DigitalOcean)
  static const String baseUrl = 'https://wie-app-dacqb.ondigitalocean.app';
  // Local dev: 'http://10.0.2.2:8000' (emulator) or 'http://YOUR_IP:8000' (device)
  
  // API Endpoints (your backend uses /api/auth, not /api/v1/auth)
  static const String loginEndpoint = '/api/auth/login';
  static const String registerEndpoint = '/api/auth/register';
  static const String profileEndpoint = '/api/auth/me';
  static const String forgotPasswordEndpoint = '/api/auth/forgot-password';
  static const String resetPasswordEndpoint = '/api/auth/reset-password';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String userRoleKey = 'user_role';
}
