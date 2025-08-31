from django.db import models
from apps.users.models import UserProfile
from apps.shops.models import Shop
from apps.orders.models import Order, OrderItem

class PaymentMethod(models.Model):
    METHOD_TYPE_CHOICES = [
        ('card', 'Card'),
        ('wallet', 'Wallet'),
        ('bank', 'Bank'),
        ('cod', 'Cash on Delivery'),
    ]

    method_id = models.BigAutoField(primary_key=True)
    method_name = models.CharField(max_length=100)
    method_type = models.CharField(max_length=10, choices=METHOD_TYPE_CHOICES)
    gateway_name = models.CharField(max_length=100, null=True, blank=True)
    is_active = models.BooleanField(default=True)
    configuration_json = models.JSONField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.method_name

class Transaction(models.Model):
    TRANSACTION_TYPE_CHOICES = [
        ('payment', 'Payment'),
        ('refund', 'Refund'),
        ('commission', 'Commission'),
        ('payout', 'Payout'),
        ('wallet_deposit', 'Wallet Deposit'),
        ('wallet_withdrawal', 'Wallet Withdrawal'),
    ]
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
    ]

    transaction_id = models.BigAutoField(primary_key=True)
    order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True)
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.SET_NULL, null=True, blank=True)
    transaction_type = models.CharField(max_length=20, choices=TRANSACTION_TYPE_CHOICES)
    amount = models.DecimalField(max_digits=15, decimal_places=2)
    currency = models.CharField(max_length=10)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES)
    gateway_transaction_id = models.CharField(max_length=255, null=True, blank=True)
    gateway_response_json = models.JSONField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.transaction_type} - {self.amount} {self.currency}"

class Commission(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('cleared', 'Cleared'),
        ('paid_out', 'Paid Out'),
        ('disputed', 'Disputed'),
    ]

    commission_id = models.BigAutoField(primary_key=True)
    order = models.ForeignKey(Order, on_delete=models.CASCADE)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE)
    item = models.ForeignKey(OrderItem, on_delete=models.CASCADE)
    commission_rate = models.DecimalField(max_digits=5, decimal_places=2)
    gross_amount = models.DecimalField(max_digits=12, decimal_places=2)
    commission_amount = models.DecimalField(max_digits=10, decimal_places=2)
    platform_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    net_amount = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    calculated_at = models.DateTimeField(auto_now_add=True)

class Payout(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ]

    payout_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey(Shop, on_delete=models.RESTRICT)
    payout_amount = models.DecimalField(max_digits=15, decimal_places=2)
    currency = models.CharField(max_length=10)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES)
    payout_method = models.CharField(max_length=100, null=True, blank=True)
    bank_details_json = models.JSONField(null=True, blank=True)
    requested_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    reference_number = models.CharField(max_length=255, null=True, blank=True)

class PayoutTransaction(models.Model):
    payout_transaction_id = models.BigAutoField(primary_key=True)
    payout = models.ForeignKey(Payout, on_delete=models.CASCADE)
    commission = models.ForeignKey(Commission, on_delete=models.CASCADE)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('payout', 'commission')

class Invoice(models.Model):
    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('sent', 'Sent'),
        ('paid', 'Paid'),
        ('overdue', 'Overdue'),
        ('void', 'Void'),
    ]

    invoice_id = models.BigAutoField(primary_key=True)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE)
    invoice_number = models.CharField(max_length=50, unique=True)
    billing_period_start = models.DateField()
    billing_period_end = models.DateField()
    subtotal = models.DecimalField(max_digits=12, decimal_places=2)
    tax_amount = models.DecimalField(max_digits=12, decimal_places=2)
    total_amount = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES)
    generated_at = models.DateTimeField(auto_now_add=True)
    due_date = models.DateField(null=True, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)

class FinancialReport(models.Model):
    report_id = models.BigAutoField(primary_key=True)
    report_type = models.CharField(max_length=100)
    shop = models.ForeignKey(Shop, on_delete=models.SET_NULL, null=True, blank=True)
    report_data_json = models.JSONField()
    period_start = models.DateField()
    period_end = models.DateField()
    generated_at = models.DateTimeField(auto_now_add=True)

class WalletTransaction(models.Model):
    TRANSACTION_TYPE_CHOICES = [
        ('deposit', 'Deposit'),
        ('withdrawal', 'Withdrawal'),
        ('payment', 'Payment'),
        ('refund_credit', 'Refund Credit'),
    ]

    wallet_transaction_id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    transaction_type = models.CharField(max_length=20, choices=TRANSACTION_TYPE_CHOICES)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    balance_after = models.DecimalField(max_digits=12, decimal_places=2)
    description = models.CharField(max_length=255, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
