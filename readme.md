# Iris 小瞳

Repo: https://github.com/hackape/iris-gemma-vision

利用 Gemma 的多模态视觉能力做环境描述，辅助视障人士完成步行导航、物品识别等日常任务。

核心功能较为简单：拍照输入 Gemma 模型，转换成文字描述，再用 TTS 朗读出来。

Demo App 的主要精力放在适配 Voiceover，以符合视障人士的使用习惯。同时做了国际化适配，根据用户的语言设置，返回对应语言的环境描述。

## Demo

https://youtube.com/shorts/UbYVAdqUo_k?si=KBR7Au4iy0vWYrGL

## 后续迭代计划

1. 调整提示词，引入「使用场景」概念，引导模型依据不同使用场景，返回不同侧重点的环境描述
2. 增加 Live 模式，让用户可以用语音指令完成操作，不需要点击
3. 目前 cloud inference 延迟还是较高，考虑接入 Gemma-3n 做 on-device inference，降低响应时间
