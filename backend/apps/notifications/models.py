from django.db import models
from apps.users.models import UserProfile

class NotificationTemplate(models.Model):
    TEMPLATE_TYPE_CHOICES = [
        ('email', 'Email'),
        ('sms', 'SMS'),
        ('push', 'Push'),
        ('in_app', 'In-App'),
    ]

    template_id = models.BigAutoField(primary_key=True)
    template_name = models.CharField(max_length=255, unique=True)
    template_type = models.CharField(max_length=10, choices=TEMPLATE_TYPE_CHOICES)
    subject_template = models.CharField(max_length=512, null=True, blank=True)
    body_template = models.TextField()
    variables_json = models.JSONField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.template_name

class Notification(models.Model):
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
    ]
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('sent', 'Sent'),
        ('delivered', 'Delivered'),
        ('failed', 'Failed'),
        ('read', 'Read'),
    ]

    notification_id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    template = models.ForeignKey(NotificationTemplate, on_delete=models.SET_NULL, null=True, blank=True)
    notification_type = models.CharField(max_length=100)
    title = models.CharField(max_length=512, null=True, blank=True)
    message = models.TextField()
    data_json = models.JSONField(null=True, blank=True)
    channels_json = models.JSONField()
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='medium')
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)

class NotificationPreference(models.Model):
    preference_id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    notification_type = models.CharField(max_length=100)
    email_enabled = models.BooleanField(default=True)
    sms_enabled = models.BooleanField(default=False)
    push_enabled = models.BooleanField(default=True)
    in_app_enabled = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'notification_type')

class NotificationLog(models.Model):
    CHANNEL_CHOICES = [
        ('email', 'Email'),
        ('sms', 'SMS'),
        ('push', 'Push'),
        ('in_app', 'In-App'),
    ]
    STATUS_CHOICES = [
        ('success', 'Success'),
        ('failed', 'Failed'),
        ('deferred', 'Deferred'),
    ]

    log_id = models.BigAutoField(primary_key=True)
    notification = models.ForeignKey(Notification, on_delete=models.CASCADE)
    channel = models.CharField(max_length=10, choices=CHANNEL_CHOICES)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES)
    response_data_json = models.JSONField(null=True, blank=True)
    attempted_at = models.DateTimeField(auto_now_add=True)
    delivered_at = models.DateTimeField(null=True, blank=True)

class PushSubscription(models.Model):
    subscription_id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(UserProfile, to_field='keycloak_user_id', on_delete=models.CASCADE)
    endpoint = models.URLField(max_length=2048, unique=True)
    p256dh_key = models.CharField(max_length=255)
    auth_key = models.CharField(max_length=255)
    user_agent = models.CharField(max_length=512, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

class EmailCampaign(models.Model):
    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('scheduled', 'Scheduled'),
        ('sending', 'Sending'),
        ('sent', 'Sent'),
        ('cancelled', 'Cancelled'),
    ]

    campaign_id = models.BigAutoField(primary_key=True)
    campaign_name = models.CharField(max_length=255)
    template = models.ForeignKey(NotificationTemplate, on_delete=models.RESTRICT)
    target_audience_json = models.JSONField(null=True, blank=True)
    scheduled_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='draft')
    created_by = models.CharField(max_length=255, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

class NotificationQueue(models.Model):
    CHANNEL_CHOICES = [
        ('email', 'Email'),
        ('sms', 'SMS'),
        ('push', 'Push'),
        ('in_app', 'In-App'),
    ]

    queue_id = models.BigAutoField(primary_key=True)
    notification = models.ForeignKey(Notification, on_delete=models.CASCADE)
    channel = models.CharField(max_length=10, choices=CHANNEL_CHOICES)
    priority = models.IntegerField(default=10)
    scheduled_at = models.DateTimeField()
    attempts = models.PositiveIntegerField(default=0)
    max_attempts = models.PositiveIntegerField(default=3)
    created_at = models.DateTimeField(auto_now_add=True)
