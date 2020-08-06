#!/bin/bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Run the test, assuming it's already in the target directory.
# Requirements:
# The current directory is the test target directory.
# Env var `PROJECT_ROOT` is defined.

echo "------------------------------------------------------------"
echo "- testing ${PWD}"
echo "------------------------------------------------------------"

# If no local noxfile exists, copy the one from root
if [[ ! -f "noxfile.py" ]]; then
    PARENT_DIR=$(cd ../ && pwd)
    while [[ "$PARENT_DIR" != "${PROJECT_ROOT}" && \
		 ! -f "$PARENT_DIR/noxfile-template.py" ]];
    do
        PARENT_DIR=$(dirname "$PARENT_DIR")
    done
    cp "$PARENT_DIR/noxfile-template.py" "./noxfile.py"
    echo -e "\n Using noxfile-template from parent folder ($PARENT_DIR). \n"
    cleanup_noxfile=1
else
    cleanup_noxfile=0
fi

# Use nox to execute the tests for the project.
nox -s "$RUN_TESTS_SESSION"
EXIT=$?

# Inject region tag data into the test log
REGION_TAG_PARSER_DIR="$PARENT_DIR/region-tag-parser"
pip install pyyaml
if [ ! -d "$REGION_TAG_PARSER_DIR" ]; then
    git clone https://github.com/GoogleCloudPlatform/repo-automation-playground "$REGION_TAG_PARSER_DIR" --single-branch --branch python-fixes
fi

PARSER_PATH="$REGION_TAG_PARSER_DIR/wizard-py/cli.py"
XUNIT_PATH="$PWD/sponge_log.xml"
XUNIT_TMP_PATH="$PWD/drift_tmp.xml"

chmod +x "$PARSER_PATH"

cp $XUNIT_PATH $XUNIT_TMP_PATH
cat "$XUNIT_TMP_PATH" | python3.8 "$PARSER_PATH" inject-snippet-mapping "$PWD" > "$XUNIT_PATH"

# If REPORT_TO_BUILD_COP_BOT is set to "true", send the test log
# to the Build Cop Bot.
# See:
# https://github.com/googleapis/repo-automation-bots/tree/master/packages/buildcop.
if [[ "${REPORT_TO_BUILD_COP_BOT:-}" == "true" ]]; then
    chmod +x $KOKORO_GFILE_DIR/linux_amd64/buildcop
    $KOKORO_GFILE_DIR/linux_amd64/buildcop
fi

if [[ "${EXIT}" -ne 0 ]]; then
    echo -e "\n Testing failed: Nox returned a non-zero exit code. \n"
else
    echo -e "\n Testing completed.\n"
fi

# Remove noxfile.py if we copied.
if [[ $cleanup_noxfile -eq 1 ]]; then
    rm noxfile.py
fi

exit ${EXIT}
