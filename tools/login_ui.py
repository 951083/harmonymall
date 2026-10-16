# -*- coding: utf-8 -*-
"""
在模拟器上完成登录（凭据从 login-body.json 读取，避免出现在命令行里）

关键点：软键盘弹起后页面会整体上移，输入框坐标随之变化。
因此每填完一个框都必须先收键盘、再重新 dump 布局定位下一个框，
否则第二次输入会落到第一个框上（表现为文本被拼了两遍）。
"""
import json
import os
import time

import uitool

HERE = os.path.dirname(os.path.abspath(__file__))


def find_inputs():
    tree = uitool.dump()
    result = []
    for n in uitool.all_nodes(tree):
        a = n.get("attributes", {})
        if "TextInput" in (a.get("type") or ""):
            c = uitool.center(a.get("bounds", ""))
            if c:
                result.append(c)
    return result


def fill(index, text):
    inputs = find_inputs()
    if len(inputs) <= index:
        print("第 %d 个输入框不存在，当前 %d 个" % (index, len(inputs)))
        return False
    x, y = inputs[index]
    uitool.hdc("shell", "uitest uiInput inputText %d %d %s" % (x, y, text))
    time.sleep(0.6)
    uitool.hdc("shell", "uitest uiInput keyEvent 2")  # 收起键盘，恢复页面位置
    time.sleep(0.8)
    return True


def main():
    with open(os.path.join(HERE, "login-body.json"), encoding="utf-8") as f:
        cred = json.load(f)
    ok1 = fill(0, cred["username"])
    ok2 = fill(1, cred["password"])
    print("填写结果: user=%s pwd=%s" % (ok1, ok2))


if __name__ == "__main__":
    main()
