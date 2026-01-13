#!/usr/bin/env bash
# 启用严格模式： errexit、nounset、pipefail
set -o errexit -o nounset -o pipefail

# 验证初始化基础镜像的输出以'Created: img_'开头
[[ "$(./bocker init ~/base-image)" ==  'Created: img_'* ]]
