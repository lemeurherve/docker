#!/usr/bin/env bats

# bats file_tags=test-suite:bake
# bats file_tags=test-type:golden-file

load test_helpers

SUT_DESCRIPTION="docker bake"
# Tracked by updatecli
LATEST_WEEKLY_JENKINS_VERSION="2.592"
LATEST_LTS_JENKINS_VERSION="2.580.3"
# Fixed versions
OLDER_WEEKLY_JENKINS_VERSION="2.590"
OLDER_LTS_JENKINS_VERSION="2.555.1"

@test "[${SUT_DESCRIPTION}: tags] Latest weekly tags unchanged" {
  assert_matches_golden expected_tags_latest_weekly make --silent tags JENKINS_VERSION="${LATEST_WEEKLY_JENKINS_VERSION}"
}
@test "[${SUT_DESCRIPTION}: tags] Latest LTS tags unchanged" {
  assert_matches_golden expected_tags_latest_lts make --silent tags JENKINS_VERSION="${LATEST_LTS_JENKINS_VERSION}"
}
@test "[${SUT_DESCRIPTION}: tags] Older weekly tags unchanged" {
  assert_matches_golden expected_tags_older_weekly make --silent tags JENKINS_VERSION="${OLDER_WEEKLY_JENKINS_VERSION}"
}
@test "[${SUT_DESCRIPTION}: tags] Older LTS tags unchanged" {
  assert_matches_golden expected_tags_older_lts make --silent tags JENKINS_VERSION="${OLDER_LTS_JENKINS_VERSION}"
}

@test "[${SUT_DESCRIPTION}: platforms] Platforms per target unchanged" {
  assert_matches_golden expected_platforms make --silent platforms
}
