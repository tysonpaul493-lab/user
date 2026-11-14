<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('otp_codes', function (Blueprint $table) {
            $table->id();
            $table->string('scope', 16)->default('driver'); // driver | user
            $table->string('phone_key', 32)->index();
            $table->string('e164_phone', 32)->nullable();
            $table->string('otp_code', 12);
            $table->timestamp('expires_at');
            $table->timestamps();

            $table->unique(['scope', 'phone_key']);
        });

        Schema::create('drivers', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('phone', 32);
            $table->string('phone_key', 32)->unique();
            $table->string('email', 191)->default('');
            $table->string('emergency_contact', 64)->default('');
            $table->string('license_number', 64)->default('');
            $table->string('license_expiry_date', 32)->default('');
            $table->decimal('rating', 4, 2)->default(4.95);
            $table->unsignedInteger('total_trips')->default(0);
            $table->string('vehicle_number', 32)->default('TN-01-EA-1080');
            $table->string('vehicle_plate', 32)->default('TN-01-EA-1080');
            $table->string('vehicle_type', 32)->default('als');
            $table->string('vehicle_type_display', 100)->default('Advanced Life Support (ALS)');
            $table->string('vehicle_model', 120)->default('Force Traveller ICU Ambulance');
            $table->unsignedSmallInteger('vehicle_year')->default(2024);
            $table->json('equipment_list')->nullable();
            $table->string('operator_affiliation', 150)->default('108 Emergency Services');
            $table->string('permit_number', 64)->default('');
            $table->string('permit_expiry_date', 32)->default('');
            $table->string('insurance_policy_number', 64)->default('');
            $table->string('insurance_expiry_date', 32)->default('');
            $table->json('documents_uploaded')->nullable();
            $table->string('verification_status', 32)->default('approved');
            $table->boolean('is_online')->default(true);
            $table->double('lat')->default(11.0210);
            $table->double('lng')->default(76.9380);
            $table->double('heading')->default(0.0);
            $table->double('speed')->default(0.0);
            $table->timestamps();
        });

        Schema::create('driver_phone_aliases', function (Blueprint $table) {
            $table->id();
            $table->string('phone_key', 32)->unique();
            $table->foreignId('driver_id')->constrained('drivers')->cascadeOnDelete();
            $table->timestamps();
        });

        Schema::create('driver_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_id')->constrained('drivers')->cascadeOnDelete();
            $table->string('token', 191)->unique();
            $table->string('device_name', 120)->default('Driver Mobile App');
            $table->timestamps();
        });

        Schema::create('driver_documents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_id')->constrained('drivers')->cascadeOnDelete();
            $table->string('document_type', 64);
            $table->string('original_filename')->nullable();
            $table->string('mime_type', 100)->nullable();
            $table->string('file_path')->nullable();
            $table->timestamps();
        });

        Schema::create('bookings', function (Blueprint $table) {
            $table->unsignedBigInteger('id')->primary();
            $table->string('booking_reference', 32)->unique();
            $table->string('reference_number', 32)->unique();
            $table->foreignId('driver_id')->nullable()->constrained('drivers')->nullOnDelete();
            $table->string('status', 48)->default('finding_ambulance')->index();
            $table->double('pickup_lat')->default(12.9716);
            $table->double('pickup_lng')->default(77.5946);
            $table->string('pickup_address')->default('Current GPS Position');
            $table->string('pickup_landmark')->default('');
            $table->string('callback_phone', 32)->default('');
            $table->string('patient_name')->default('');
            $table->string('emergency_category', 100)->default('General Emergency');
            $table->text('notes')->nullable();
            $table->text('essential_instructions')->nullable();
            $table->json('destination_hospital')->nullable();
            $table->string('destination_address')->default('Casualty & Emergency Bay');
            $table->double('destination_latitude')->default(12.9866);
            $table->double('destination_longitude')->default(77.6066);
            $table->unsignedInteger('eta_minutes')->default(0);
            $table->double('distance_km')->default(0.0);
            $table->double('distance_meters')->default(0.0);
            $table->text('cancel_reason')->nullable();
            $table->text('handover_notes')->nullable();
            $table->unsignedInteger('duration_minutes')->default(18);
            $table->double('earnings')->default(350.0);
            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('arrived_pickup_at')->nullable();
            $table->timestamp('patient_picked_up_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();
        });

        Schema::create('booking_declines', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('booking_id');
            $table->foreignId('driver_id')->constrained('drivers')->cascadeOnDelete();
            $table->timestamps();

            $table->foreign('booking_id')->references('id')->on('bookings')->cascadeOnDelete();
            $table->unique(['booking_id', 'driver_id']);
        });

        Schema::create('booking_chat_messages', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('booking_id')->index();
            $table->string('booking_reference', 32)->index();
            $table->string('sender', 32)->default('user');
            $table->text('message');
            $table->timestamps();
        });

        Schema::create('driver_notifications', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('booking_id')->nullable()->index();
            $table->string('booking_reference', 32)->nullable();
            $table->string('title');
            $table->text('message');
            $table->string('type', 64)->default('new_booking');
            $table->json('request_payload')->nullable();
            $table->boolean('is_read')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('driver_notifications');
        Schema::dropIfExists('booking_chat_messages');
        Schema::dropIfExists('booking_declines');
        Schema::dropIfExists('bookings');
        Schema::dropIfExists('driver_documents');
        Schema::dropIfExists('driver_tokens');
        Schema::dropIfExists('driver_phone_aliases');
        Schema::dropIfExists('drivers');
        Schema::dropIfExists('otp_codes');
    }
};
