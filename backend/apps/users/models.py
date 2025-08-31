from django.db import models

class UserProfile(models.Model):
    GENDER_CHOICES = [
        ('male', 'Male'),
        ('female', 'Female'),
        ('other', 'Other'),
        ('prefer_not_to_say', 'Prefer not to say'),
    ]
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('inactive', 'Inactive'),
        ('suspended', 'Suspended'),
    ]

    profile_id = models.BigAutoField(primary_key=True)
    keycloak_user_id = models.CharField(max_length=255, unique=True)
    email = models.EmailField(max_length=255)
    phone = models.CharField(max_length=50, null=True, blank=True)
    first_name = models.CharField(max_length=100, null=True, blank=True)
    last_name = models.CharField(max_length=100, null=True, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=20, choices=GENDER_CHOICES, null=True, blank=True)
    avatar_url = models.URLField(max_length=2048, null=True, blank=True)
    bio = models.TextField(null=True, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='active')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_sync_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return self.email

class UserAddress(models.Model):
    ADDRESS_TYPE_CHOICES = [
        ('home', 'Home'),
        ('work', 'Work'),
        ('billing', 'Billing'),
        ('shipping', 'Shipping'),
    ]

    address_id = models.BigAutoField(primary_key=True)
    user_profile = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE, related_name='addresses')
    address_type = models.CharField(max_length=10, choices=ADDRESS_TYPE_CHOICES)
    address_line1 = models.CharField(max_length=255)
    address_line2 = models.CharField(max_length=255, null=True, blank=True)
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100, null=True, blank=True)
    country = models.CharField(max_length=100)
    postal_code = models.CharField(max_length=20)
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user_profile.email} - {self.address_type}"

class UserBusinessData(models.Model):
    KYC_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('resubmit_required', 'Resubmit Required'),
    ]

    business_id = models.BigAutoField(primary_key=True)
    user_profile = models.OneToOneField(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE, related_name='business_data')
    kyc_status = models.CharField(max_length=20, choices=KYC_STATUS_CHOICES, default='pending')
    kyc_documents_json = models.JSONField(null=True, blank=True)
    tax_id = models.CharField(max_length=100, null=True, blank=True)
    business_license = models.CharField(max_length=255, null=True, blank=True)
    business_type = models.CharField(max_length=100, null=True, blank=True)
    verification_notes = models.TextField(null=True, blank=True)
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.CharField(max_length=255, null=True, blank=True) # Could be a FK to an admin user profile

    def __str__(self):
        return f"Business data for {self.user_profile.email}"

class KeycloakUserSync(models.Model):
    SYNC_STATUS_CHOICES = [
        ('success', 'Success'),
        ('failed', 'Failed'),
    ]

    sync_id = models.BigAutoField(primary_key=True)
    user_profile = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE, related_name='sync_logs')
    last_sync_at = models.DateTimeField(auto_now_add=True)
    sync_status = models.CharField(max_length=10, choices=SYNC_STATUS_CHOICES)
    error_message = models.TextField(null=True, blank=True)
    attributes_synced_json = models.JSONField(null=True, blank=True)

    def __str__(self):
        return f"Sync log for {self.user_profile.email} at {self.last_sync_at}"

class UserPreference(models.Model):
    THEME_CHOICES = [
        ('light', 'Light'),
        ('dark', 'Dark'),
    ]

    preference_id = models.BigAutoField(primary_key=True)
    user_profile = models.OneToOneField(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE, related_name='preferences')
    notification_email = models.BooleanField(default=True)
    notification_sms = models.BooleanField(default=False)
    notification_push = models.BooleanField(default=True)
    language = models.CharField(max_length=10, default='en-US')
    currency = models.CharField(max_length=10, default='USD')
    timezone = models.CharField(max_length=50, default='UTC')
    theme = models.CharField(max_length=10, choices=THEME_CHOICES, default='light')
    marketing_consent = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Preferences for {self.user_profile.email}"

class ShopUserRole(models.Model):
    role_assignment_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey('shops.Shop', on_delete=models.CASCADE)
    user_profile = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    keycloak_role_name = models.CharField(max_length=100)
    assigned_at = models.DateTimeField(auto_now_add=True)
    assigned_by = models.CharField(max_length=255, null=True, blank=True) # Keycloak ID of assigner
    is_active = models.BooleanField(default=True)

    class Meta:
        unique_together = ('shop', 'user_profile', 'keycloak_role_name')

    def __str__(self):
        return f"{self.user_profile.email} - {self.keycloak_role_name} in shop {self.shop_id}"

class UserActivityLog(models.Model):
    activity_id = models.BigAutoField(primary_key=True)
    user_profile = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.SET_NULL, null=True, blank=True)
    activity_type = models.CharField(max_length=100)
    resource_type = models.CharField(max_length=100, null=True, blank=True)
    resource_id = models.CharField(max_length=255, null=True, blank=True)
    ip_address = models.GenericIPAddressField()
    user_agent = models.CharField(max_length=512, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user_profile.email} - {self.activity_type} at {self.created_at}"
