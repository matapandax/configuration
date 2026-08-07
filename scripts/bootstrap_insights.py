"""Create missing Koa Insights result tables and the API service account."""

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import connections
from rest_framework.authtoken.models import Token

from analytics_data_api.v0.models import (
    CourseEnrollmentByCountry, GradeDistribution, ModuleEngagement,
    ModuleEngagementMetricRanges, ProblemFirstLastResponseAnswerDistribution,
    ProblemsAndTags, SequentialOpenDistribution, Video, VideoTimeline,
)

models = [
    CourseEnrollmentByCountry, ProblemsAndTags,
    ProblemFirstLastResponseAnswerDistribution, Video, VideoTimeline,
    ModuleEngagement, ModuleEngagementMetricRanges, GradeDistribution,
    SequentialOpenDistribution,
]

connection = connections[settings.ANALYTICS_DATABASE]
existing = set(connection.introspection.table_names())
created = []
with connection.schema_editor() as editor:
    for model in models:
        if model._meta.db_table not in existing:
            editor.create_model(model)
            created.append(model._meta.db_table)

user_model = get_user_model()
api_user, _ = user_model.objects.get_or_create(
    username="insights", defaults={"is_active": True}
)
api_user.is_active = True
api_user.set_unusable_password()
api_user.save()
Token.objects.filter(key=settings.API_AUTH_TOKEN).exclude(user=api_user).delete()
Token.objects.update_or_create(
    user=api_user, defaults={"key": settings.API_AUTH_TOKEN}
)

print("Created report tables: {}".format(", ".join(created) or "none"))
print("Insights API service account is ready")
