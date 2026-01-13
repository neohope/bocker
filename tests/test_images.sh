#!/usr/bin/env bash
# 启用严格模式： errexit、nounset、pipefail
set -o errexit -o nounset -o pipefail

# 验证bocker images命令首行输出为指定表头
[[ "$(./bocker images | head -n 1)" == 'IMAGE_ID		SOURCE' ]]
