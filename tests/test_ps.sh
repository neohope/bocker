#!/usr/bin/env bash
# 启用严格模式： errexit、nounset、pipefail
set -o errexit -o nounset -o pipefail

# 验证bocker ps命令首行输出为指定表头
[[ "$(./bocker ps | head -n 1)" == 'CONTAINER_ID		COMMAND' ]]
