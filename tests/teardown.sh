#!/usr/bin/env bash
# 启用严格模式： errexit、nounset、pipefail
set -o errexit -o nounset -o pipefail

# 遍历所有包含'img'的镜像ID，执行删除操作
for img in $(./bocker images | grep 'img' | awk '{print $1}'); do
	./bocker rm "$img"
done

# 遍历所有包含'ps'的容器ID，执行删除操作
for ps in $(./bocker ps | grep 'ps' | awk '{print $1}'); do
	./bocker rm "$ps"
done
