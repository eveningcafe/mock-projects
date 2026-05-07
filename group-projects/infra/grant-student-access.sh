#!/usr/bin/env bash
# Grant cluster-admin access to a list of student IAM users on the EKS cluster.
# Usage: ./grant-student-access.sh DE000111 DE000135 ...
# Or:    ./grant-student-access.sh < students.txt   (one username per line)
#
# Prereqs: cluster auth mode must be API or API_AND_CONFIG_MAP.

set -e

CLUSTER=${CLUSTER:-group-projects-eks}
REGION=${REGION:-ap-southeast-1}
ACCOUNT=${ACCOUNT:-$(aws sts get-caller-identity --query Account --output text)}
POLICY=${POLICY:-arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy}

if [ $# -gt 0 ]; then
  USERS="$@"
else
  USERS=$(cat)
fi

for u in $USERS; do
  ARN=arn:aws:iam::$ACCOUNT:user/$u
  echo "--- $u ---"
  aws eks create-access-entry --cluster-name "$CLUSTER" --region "$REGION" --principal-arn "$ARN" --type STANDARD 2>&1 | grep -E 'principalArn|error|already' || true
  aws eks associate-access-policy --cluster-name "$CLUSTER" --region "$REGION" --principal-arn "$ARN" --policy-arn "$POLICY" --access-scope type=cluster 2>&1 | grep -E 'policyArn|error|already' || true
done
