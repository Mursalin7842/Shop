from django.db import models
from apps.shops.models import Shop
from apps.users.models import UserProfile
from apps.orders.models import Order

class Coupon(models.Model):
    DISCOUNT_TYPE_CHOICES = [
        ('percentage', 'Percentage'),
        ('fixed_amount', 'Fixed Amount'),
        ('free_shipping', 'Free Shipping'),
    ]

    coupon_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True)
    coupon_code = models.CharField(max_length=100, unique=True)
    coupon_name = models.CharField(max_length=255, null=True, blank=True)
    description = models.TextField(null=True, blank=True)
    discount_type = models.CharField(max_length=15, choices=DISCOUNT_TYPE_CHOICES)
    discount_value = models.DecimalField(max_digits=10, decimal_places=2)
    minimum_order_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    maximum_discount_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    is_active = models.BooleanField(default=True)
    starts_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    usage_limit = models.PositiveIntegerField(null=True, blank=True)
    usage_limit_per_customer = models.PositiveIntegerField(null=True, blank=True)
    created_by = models.CharField(max_length=255, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.coupon_code

class CouponUsage(models.Model):
    usage_id = models.BigAutoField(primary_key=True)
    coupon = models.ForeignKey(Coupon, on_delete=models.CASCADE, related_name='usages')
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    order = models.ForeignKey(Order, on_delete=models.CASCADE)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2)
    used_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('coupon', 'order')

class DiscountPolicy(models.Model):
    POLICY_TYPE_CHOICES = [
        ('bulk_purchase', 'Bulk Purchase'),
        ('category_wide', 'Category Wide'),
        ('customer_group', 'Customer Group'),
    ]

    policy_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE)
    policy_name = models.CharField(max_length=255)
    policy_type = models.CharField(max_length=20, choices=POLICY_TYPE_CHOICES)
    conditions_json = models.JSONField()
    discount_json = models.JSONField()
    is_active = models.BooleanField(default=True)
    priority = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

class PromotionalCampaign(models.Model):
    campaign_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, null=True, blank=True)
    campaign_name = models.CharField(max_length=255)
    campaign_type = models.CharField(max_length=100, null=True, blank=True)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    budget = models.DecimalField(max_digits=15, decimal_places=2, null=True, blank=True)
    target_audience_json = models.JSONField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

class CampaignCoupon(models.Model):
    campaign_coupon_id = models.BigAutoField(primary_key=True)
    campaign = models.ForeignKey(PromotionalCampaign, on_delete=models.CASCADE)
    coupon = models.ForeignKey(Coupon, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('campaign', 'coupon')

class CustomerDiscountEligibility(models.Model):
    eligibility_id = models.BigAutoField(primary_key=True)
    customer = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    discount_policy = models.ForeignKey(DiscountPolicy, on_delete=models.CASCADE)
    is_eligible = models.BooleanField(default=False)
    calculated_at = models.DateTimeField()

    class Meta:
        unique_together = ('customer', 'discount_policy')

class DiscountUsageAnalytics(models.Model):
    analytics_id = models.BigAutoField(primary_key=True)
    coupon = models.ForeignKey(Coupon, on_delete=models.SET_NULL, null=True, blank=True)
    date = models.DateField()
    usage_count = models.PositiveIntegerField()
    total_discount_amount = models.DecimalField(max_digits=15, decimal_places=2)
    revenue_impact = models.DecimalField(max_digits=15, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('coupon', 'date')
