from django.db import models
from apps.users.models import UserProfile

class Shop(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('suspended', 'Suspended'),
        ('rejected', 'Rejected'),
    ]

    shop_id = models.BigAutoField(primary_key=True)
    owner = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.RESTRICT)
    shop_name = models.CharField(max_length=255)
    shop_slug = models.SlugField(max_length=255, unique=True)
    city = models.CharField(max_length=100, null=True, blank=True)
    state = models.CharField(max_length=100, null=True, blank=True)
    country = models.CharField(max_length=100, null=True, blank=True)
    address = models.TextField(null=True, blank=True)
    zip_code = models.CharField(max_length=20, null=True, blank=True)
    phone = models.CharField(max_length=50, null=True, blank=True)
    email = models.EmailField(max_length=255, null=True, blank=True)
    description = models.TextField(null=True, blank=True)
    logo_url = models.URLField(max_length=2048, null=True, blank=True)
    banner_url = models.URLField(max_length=2048, null=True, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    approval_date = models.DateTimeField(null=True, blank=True)
    approved_by = models.CharField(max_length=255, null=True, blank=True) # Keycloak ID of admin
    commission_rate = models.DecimalField(max_digits=5, decimal_places=2, default=10.00)
    minimum_payout_amount = models.DecimalField(max_digits=10, decimal_places=2, default=50.00)
    shop_type = models.CharField(max_length=100, null=True, blank=True)
    business_license = models.CharField(max_length=255, null=True, blank=True)
    tax_id = models.CharField(max_length=100, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.shop_name

class ShopCategory(models.Model):
    category_id = models.BigAutoField(primary_key=True)
    category_name = models.CharField(max_length=255, unique=True)
    description = models.TextField(null=True, blank=True)
    commission_rate_override = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.category_name

class ShopCategoryAssignment(models.Model):
    assignment_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE)
    category = models.ForeignKey(ShopCategory, on_delete=models.CASCADE)
    assigned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('shop', 'category')

class ShopPolicy(models.Model):
    policy_id = models.BigAutoField(primary_key=True)
    shop = models.OneToOneField(Shop, on_delete=models.CASCADE, related_name='policies')
    return_policy = models.TextField(null=True, blank=True)
    shipping_policy = models.TextField(null=True, blank=True)
    privacy_policy = models.TextField(null=True, blank=True)
    terms_of_service = models.TextField(null=True, blank=True)
    refund_policy = models.TextField(null=True, blank=True)
    created__at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Policies for {self.shop.shop_name}"

class ShopSetting(models.Model):
    setting_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='settings')
    setting_key = models.CharField(max_length=100)
    setting_value = models.TextField()
    setting_type = models.CharField(max_length=50, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('shop', 'setting_key')

class ShopStaff(models.Model):
    ROLE_CHOICES = [
        ('manager', 'Manager'),
        ('staff', 'Staff'),
        ('viewer', 'Viewer'),
    ]
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('inactive', 'Inactive'),
    ]

    staff_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='staff')
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    role = models.CharField(max_length=10, choices=ROLE_CHOICES)
    permissions_json = models.JSONField(null=True, blank=True)
    hired_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='active')

    class Meta:
        unique_together = ('shop', 'user')

    def __str__(self):
        return f"{self.user.email} - {self.role} at {self.shop.shop_name}"

class ShopStatistics(models.Model):
    stat_id = models.BigAutoField(primary_key=True)
    shop = models.OneToOneField(Shop, on_delete=models.CASCADE, related_name='statistics')
    total_products = models.PositiveIntegerField(default=0)
    total_orders = models.PositiveIntegerField(default=0)
    total_revenue = models.DecimalField(max_digits=15, decimal_places=2, default=0.00)
    average_rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.00)
    total_reviews = models.PositiveIntegerField(default=0)
    last_calculated_at = models.DateTimeField()

    def __str__(self):
        return f"Statistics for {self.shop.shop_name}"
