# 指定脚本解释器为bash
#!/usr/bin/env bash

# 初始化测试结果状态码，0=全部通过，1=存在失败
exit_code=0

# 遍历tests目录下所有test_开头的测试脚本
for t in tests/test_*; do
    # 执行环境清理脚本，清除残留镜像/容器，静默无输出
    bash tests/teardown > /dev/null 2>&1
    # 执行当前遍历到的测试用例脚本，静默无输出
    bash "$t" > /dev/null 2>&1
    # 判断上一条测试脚本执行结果，0为执行成功
    if [[ $? == 0 ]]; then
        # 输出绿色高亮的测试通过提示
        echo -e "\e[1;32mPASSED\e[0m : $t"
    else
        # 输出红色高亮的测试失败提示
        echo -e "\e[1;31mFAILED\e[0m : $t"
        # 更新状态码为1，标记存在测试失败
        exit_code=1
    fi
    # 执行环境清理脚本，清理本次测试产生的镜像/容器，静默无输出
    bash tests/teardown > /dev/null 2>&1
done

# 脚本最终退出，返回测试状态码
exit "$exit_code"
