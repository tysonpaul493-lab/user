class ApiEndpoints {
  // Authentication
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';

  // Bookings & Dispatch
  static const String createBooking = '/bookings';
  static const String cancelBooking = '/bookings/{id}/cancel';
  static const String bookingDetails = '/bookings/{id}';
  static const String bookingHistory = '/bookings/history';

  // User Profile
  static const String updateProfile = '/user/profile';

  // Hospitals
  static const String nearbyHospitals = '/hospitals/nearby';
}
