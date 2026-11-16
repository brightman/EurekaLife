/* Synthetic product-review content. No captured audio, real participants or AI calls. */
window.EurekaMeetingsData = {
  lines: [
    {speaker:'我', initials:'我', tone:'blue', time:0, text:'今天先确认会议录制的第一版范围。希望打开 Mac 就能开始，不需要邀请机器人入会。', en:'Let’s confirm the first release. Recording should start on the Mac without inviting a bot.', kind:'context'},
    {speaker:'林悦', initials:'林', tone:'green', time:6, text:'我们需要同时听到会议里的声音和自己的麦克风。戴耳机时，也应该把双方的发言记录下来。', en:'We need both meeting audio and our microphone, including when headphones are used.', kind:'context'},
    {speaker:'陈远', initials:'陈', tone:'amber', time:12, text:'建议默认只录音。演示产品或者讲解文档时，再选择录制窗口，避免把整个桌面都录进去。', en:'Audio should be the default. For demos, select a specific window instead of the whole desktop.', kind:'suggestion'},
    {speaker:'我', initials:'我', tone:'blue', time:18, text:'可以，第一版默认只录音，屏幕录制由用户主动开启。会中先看原文，会后生成有出处的总结。', en:'Agreed. Default to audio; screen capture is opt-in. Show the transcript first, then a sourced summary.', kind:'decision'},
    {speaker:'林悦', initials:'林', tone:'green', time:24, text:'我明天下午之前把录制准备页和权限异常的设计整理好，再请大家一起过一遍。', en:'I’ll prepare the setup and permission-error designs by tomorrow afternoon for review.', kind:'action', task:'整理录制准备页与权限异常设计', owner:'林悦', due:'明天下午'},
    {speaker:'陈远', initials:'陈', tone:'amber', time:30, text:'我负责验证系统声音和麦克风的采集。周五给出耳机切换、暂停恢复和长会议的测试结果。', en:'I’ll verify system and microphone capture, headphone switching, pause/resume and long sessions by Friday.', kind:'action', task:'验证双音源采集与录制恢复', owner:'陈远', due:'周五'}
  ],
  records: [
    {id:'sample-product', title:'Mac 会议录制 · 产品评审', date:'2026-11-12', time:'10:00', duration:1842, mode:'audio', language:'中文', source:'全部系统声音', mic:true, system:true, screen:'', status:'ready', star:true, count:6, category:'产品评审', marks:[18], tasks:[], messages:[]},
    {id:'sample-design', title:'设计讨论 · 录制体验', date:'2026-11-11', time:'14:30', duration:1425, mode:'screen', language:'中文', source:'会议应用窗口', mic:true, system:true, screen:'产品设计 · 示例窗口', status:'ready', star:false, count:4, category:'讨论纪要', marks:[], tasks:[], messages:[]},
    {id:'sample-planning', title:'下周计划 · 团队同步', date:'2026-11-10', time:'09:30', duration:2460, mode:'audio', language:'中文', source:'全部系统声音', mic:true, system:true, screen:'', status:'ready', star:false, count:2, category:'会议纪要', marks:[], tasks:[], messages:[]}
  ]
};
