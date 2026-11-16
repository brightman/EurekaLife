const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const out = process.env.SCREENSHOT_DIR || '/private/tmp/eurekalife-mac-components';
const base = process.env.PROTOTYPE_URL || 'http://127.0.0.1:8791';
fs.mkdirSync(out, { recursive: true });
const results = [], errors = [], failures = [], network = [];
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
 const browser = await chromium.launch();
 const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
 page.setDefaultTimeout(7000);
 page.on('pageerror', e => errors.push(String(e)));
 page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
 page.on('requestfailed', r => failures.push({ url: r.url(), error: r.failure() }));
 page.on('response', r => { if (r.status() >= 400) failures.push({ url: r.url(), status: r.status() }); });
 await page.route('**/*', route => {
  const r = route.request();
  if (!r.url().startsWith(base) || r.method() !== 'GET') {
   network.push({ url: r.url(), method: r.method() }); return route.abort();
  }
  return route.continue();
 });
 const button = name => page.getByRole('button', { name, exact: true });
 const visible = async loc => { await loc.waitFor({state:'visible'}); assert(await loc.isVisible()); };
 const expectText = async (loc, text) => { await loc.filter({hasText:text}).waitFor(); };
 const nav = async name => { const navigation = page.getByRole('navigation', { name: '主导航' }); if(name === '隐私与说明') { await navigation.getByRole('button',{name:'设置',exact:true}).click(); await page.getByRole('group',{name:'设置分类'}).getByRole('button',{name,exact:true}).click(); } else await navigation.getByRole('button', { name, exact: true }).click(); };
 const select = async (label, value) => { await page.getByRole('textbox', {name:label,exact:true}).click(); await page.getByRole('option', {name:value,exact:true}).click(); };
 const test = async (name, fn) => { if(process.env.TEST_FILTER && !new RegExp(process.env.TEST_FILTER).test(name)) return; try { await fn(); results.push({name,passed:true}); console.log('PASS',name); } catch(e) { results.push({name,passed:false,error:String(e)}); throw e; } };
 try {
 await test('Standard source provenance and documented local layout adaptation', async () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root,'src/components/standard/sources.json')));
  assert.equal(manifest.files.length,28);
  for (const f of manifest.files) assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(root,f.target))).digest('hex'), f.localSha256 || f.sha256, f.target);
 });
 await page.goto(base, {waitUntil:'networkidle'});
 await test('Meeting entry order and real component styles', async () => {
  const badge=page.getByText('演示就绪',{exact:true});
  assert.equal(await badge.evaluate(e=>getComputedStyle(e.closest('[data-status-tone]')).backgroundColor),'rgb(237, 244, 239)');
  assert.equal(await badge.evaluate(e=>getComputedStyle(e.closest('[data-status-tone]')).color),'rgb(56, 102, 76)');
  const entries = page.getByTestId('meeting-entries').getByRole('button');
  assert.equal(await entries.count(),3);
  for(const [i,label] of ['即时录音','录制会议','上传文件'].entries()) assert((await entries.nth(i).innerText()).startsWith(label));
  assert.equal(await page.locator('main').count(),1);
  assert.equal(await page.getByText('你的工作空间',{exact:true}).count(),0);
  const brand=await page.getByRole('link',{name:'EurekaLife 概览'}).boundingBox();
  const close=await button('折叠菜单').boundingBox();assert(Math.abs(brand.y+brand.height/2-close.y-close.height/2)<2);
  assert.equal(await page.getByRole('complementary',{name:'左侧菜单'}).evaluate(e=>getComputedStyle(e).width),'220px');
  assert.equal(await page.getByRole('heading',{level:1}).evaluate(e=>getComputedStyle(e).fontSize),'24px');
  const left=await page.getByRole('complementary',{name:'左侧菜单'}).boundingBox(),right=await page.getByRole('complementary',{name:'Ask AI',exact:true}).boundingBox();
  assert.equal(left.y,right.y);assert.equal(left.height,right.height);
 });
 await test('Sidebar collapse retains all five icons; keyboard and pointer resizing', async () => {
  assert.equal(await button('折叠菜单').count(),1);
  await button('折叠菜单').click();
  assert.equal(await page.getByRole('complementary',{name:'左侧菜单'}).evaluate(e=>e.clientWidth),55);
  for(const name of ['概览','模型库','会议','每日记录','设置']){
   const item=page.getByRole('navigation').getByRole('button',{name,exact:true});
   await visible(item.locator('svg'));assert((await item.boundingBox()).width>=32);
  }
  await nav('每日记录');await visible(page.getByRole('heading',{name:'每日记录',exact:true}));await nav('会议');
  assert.equal(await button('展开导航栏').count(),0);assert.equal(await button('折叠导航栏').count(),0);
  await button('展开菜单').click();
  await button('折叠菜单').evaluate(e=>e.focus());await button('折叠菜单').press('Enter');
  await sleep(50);assert(await button('展开菜单').evaluate(e=>e===document.activeElement));
  await button('展开菜单').press('Enter');await sleep(50);assert(await button('折叠菜单').evaluate(e=>e===document.activeElement));
  const left=page.getByRole('separator',{name:'调整菜单宽度'}),right=page.getByRole('separator',{name:'调整 AskAgent 宽度'});
  await left.press('ArrowRight');assert.equal(await left.getAttribute('aria-valuenow'),'228');
  await left.press('End');assert.equal(await left.getAttribute('aria-valuenow'),'400');
  await left.press('Home');assert.equal(await left.getAttribute('aria-valuenow'),'220');
  const b=await left.boundingBox();await page.mouse.move(b.x+3,b.y+120);await page.mouse.down();await page.mouse.move(b.x+43,b.y+120);await page.mouse.up();assert.equal(await left.getAttribute('aria-valuenow'),'260');await left.press('Home');
  await right.press('End');assert.equal(await right.getAttribute('aria-valuenow'),'480');await right.press('Home');assert.equal(await right.getAttribute('aria-valuenow'),'280');
  await right.press('Enter');assert.equal(await button('Ask AI').evaluate(e=>e===document.activeElement),true);await button('Ask AI').click();
  await left.press('Enter');await button('展开菜单').click();
 });
 await test('Meeting audio and video sit below recording time and above content tabs', async () => {
  for(const name of ['Mac 会议录制 · 产品评审','设计讨论 · 录制体验']) {
   await page.getByRole('button',{name:new RegExp(name)}).first().click();
   const media=page.getByRole('region',{name:'会议音视频'});
   await visible(media);
   const heading=page.getByRole('heading',{name,exact:true});
   const titleBox=await heading.boundingBox(), mediaBox=await media.boundingBox();
   const tabs=page.getByRole('tablist',{name:'会议内容'}),tabsBox=await tabs.boundingBox();
   assert(mediaBox.y>titleBox.y+titleBox.height);
   assert(mediaBox.y+mediaBox.height<=tabsBox.y);
   assert.equal(await media.getByRole('slider',{name:'演示播放位置'}).count(),1);
   for(const tab of ['总结','行动项','原文']) { await page.getByRole('tab',{name:tab,exact:true}).click();await visible(media); }
   await button('我的会议').click();
  }
 });
 await test('Settings first; audio-only starts without a screen picker', async () => {
  await page.getByTestId('meeting-entries').getByRole('button',{name:/录制会议/}).click();
  await page.getByRole('dialog',{name:'录制一场会议'}).waitFor();
  assert.equal(await page.getByRole('dialog',{name:'选择录制画面'}).count(),0);
  await page.getByRole('radio',{name:'仅录音',exact:true}).check();
  await page.getByRole('textbox',{name:'会议名称',exact:true}).fill('仅音频流程验证');
  await button('开始录制').click();await visible(page.getByTestId('recording-clock'));
  assert.equal(await page.getByRole('dialog',{name:'选择录制画面'}).count(),0);
  await expectText(page.locator('main'),'仅录音');
  await button('结束录制').click();await button('结束并整理').click();
  await page.getByRole('heading',{name:'让每场会议，都有下一步。'}).waitFor();await button('我的会议').click();
 });
 await test('Screen recording: settings validation, picker, back preserves draft, confirm starts', async () => {
  await page.getByTestId('meeting-entries').getByRole('button',{name:/即时录音/}).click();
  assert.equal(await page.getByRole('switch',{name:/^系统声音/}).isChecked(),false);
  await page.getByRole('textbox',{name:'会议名称',exact:true}).fill('组件重构验证会议');
  await page.getByRole('switch',{name:'我的麦克风',exact:true}).uncheck();assert(await button('开始录制').isDisabled());
  await page.getByRole('switch',{name:'我的麦克风',exact:true}).check();
  await page.getByRole('radio',{name:'屏幕与音频',exact:true}).check();
  await button('模拟未授权').click();assert(await button('下一步：选择画面').isDisabled());await button('模拟授权').click();
  await button('下一步：选择画面').click();await page.getByRole('dialog',{name:'选择录制画面'}).waitFor();
  assert(await button('开始录制').isDisabled());assert.equal(await page.getByTestId('recording-clock').count(),0);
  assert.equal(await page.getByRole('group',{name:'选择应用窗口',exact:true}).getByRole('button').count(),6);
  await button('产品设计 · 示例窗口').press('Enter');assert.equal(await button('产品设计 · 示例窗口').getAttribute('aria-pressed'),'true');
  await page.getByRole('tab',{name:'Entire Screen',exact:true}).click();assert(await button('开始录制').isDisabled());
  assert.equal(await page.getByRole('group',{name:'选择整个屏幕',exact:true}).getByRole('button').count(),2);
  await button('整个屏幕 · 内置显示屏').click();assert(!(await button('开始录制').isDisabled()));
  await page.getByRole('tab',{name:'Entire Screen',exact:true}).press('ArrowRight');assert(await button('开始录制').isDisabled());
  for(const width of [1280,768,390,320]) {
   await page.setViewportSize({width,height:900});await sleep(100);
   const dialog=page.getByRole('dialog',{name:'选择录制画面',exact:true});
   assert(await dialog.evaluate(e=>e.scrollWidth<=e.clientWidth+1));
   assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  }
  await page.setViewportSize({width:1600,height:1000});await button('返回设置').click();
  await page.getByRole('dialog',{name:'录制一场会议'}).waitFor();
  assert.equal(await page.getByRole('textbox',{name:'会议名称',exact:true}).inputValue(),'组件重构验证会议');
  assert.equal(await page.getByTestId('recording-clock').count(),0);
  await page.keyboard.press('Escape');await page.getByRole('dialog').waitFor({state:'hidden'});
  await page.getByTestId('meeting-entries').getByRole('button',{name:/录制会议/}).click();
  assert.equal(await page.getByRole('textbox',{name:'会议名称',exact:true}).inputValue(),'组件重构验证会议');
  await button('下一步：选择画面').click();await button('产品设计 · 示例窗口').click();
  await page.keyboard.press('Escape');await page.getByRole('dialog',{name:'录制一场会议'}).waitFor();
  await page.getByRole('radio',{name:'仅录音',exact:true}).check();assert(!(await button('开始录制').isDisabled()));
  await page.getByRole('radio',{name:'屏幕与音频',exact:true}).check();await button('下一步：选择画面').click();
  await button('产品设计 · 示例窗口').click();await button('开始录制').click();
  await visible(page.getByTestId('recording-clock'));await expectText(page.locator('main'),'产品设计 · 示例窗口');
 });
 await test('Live Ask AI is bounded to captured lines; pause, navigation and draft persistence', async () => {
  await button('暂停录制').click();
  const before=await page.getByTestId('recording-clock').innerText();await sleep(1100);assert.equal(await page.getByTestId('recording-clock').innerText(),before);
  await button('有哪些已确认的决定？').click();await expectText(page.getByTestId('chat-messages'),'目前还没有明确决定');
  const input=page.getByRole('textbox',{name:'向 Ask AI 提问',exact:true});await input.fill('保留中的中文草稿');
  await button('关闭 Ask AI').click();await button('Ask AI').click();assert.equal(await input.inputValue(),'保留中的中文草稿');
  await nav('概览');await nav('会议');assert.equal(await input.inputValue(),'保留中的中文草稿');
  await button('继续录制').click();await sleep(1100);assert.notEqual(await page.getByTestId('recording-clock').innerText(),before);
  await button('标记重点').click();await expectText(page.locator('main'),'重点');
 });
 await test('Device disconnection and transcription recovery; summary failure and retry', async () => {
  await select('演示状态','麦克风断开');assert(await button('继续录制').isDisabled());await button('切回内置麦克风并继续').click();
  await select('演示状态','转写延迟');await button('恢复转写').click();
  await select('演示状态','结束后总结失败');await button('结束录制').click();await button('结束并整理').click();
  await button('重新整理').waitFor();await button('重新整理').click();await visible(page.getByRole('heading',{name:'让每场会议，都有下一步。'}));
 });
 await test('Upload validates extensions and imports only a simulated sample', async () => {
  await button('我的会议').click();await page.getByTestId('meeting-entries').getByRole('button',{name:/上传文件/}).click();
  await page.getByLabel('选择音视频文件').setInputFiles({name:'invalid.txt',mimeType:'text/plain',buffer:Buffer.from('synthetic')});assert(await button('模拟导入并整理').isDisabled());await expectText(page.getByRole('dialog'),'请选择支持的音视频格式');
  await button('使用示例文件体验').click();await button('模拟导入并整理').click();await visible(page.getByRole('heading',{name:'产品讨论示例',exact:true}));await page.getByRole('heading',{name:'让每场会议，都有下一步。'}).waitFor();
 });
 await test('Meeting search, favorite, AI citations, stop and action editing', async () => {
  await button('我的会议').click();await page.getByRole('textbox',{name:'搜索会议',exact:true}).fill('不存在');await visible(page.getByRole('heading',{name:'没有找到会议'}));await page.getByRole('textbox',{name:'搜索会议',exact:true}).fill('');
  await page.getByRole('tab',{name:'已收藏',exact:true}).click();await page.locator('tbody').getByRole('button',{name:/^Mac 会议录制 · 产品评审/}).click();
  await button('提取行动项').click();await page.getByTestId('chat-messages').getByRole('button').first().waitFor();await page.getByTestId('chat-messages').getByRole('button').first().click();assert(await page.getByRole('tab',{name:'原文',exact:true}).getAttribute('aria-selected')==='true');
  await page.getByRole('textbox',{name:'向 Ask AI 提问',exact:true}).fill('停止验证');await button('发送问题').click();await button('停止生成').click();await sleep(900);assert(!(await page.getByTestId('chat-messages').innerText()).includes('正在整理示例内容'));
  await page.getByRole('tab',{name:'行动项',exact:true}).click();await button('加入待办').first().click();await page.getByRole('textbox',{name:'待办事项',exact:true}).fill('验证后更新产品方案');await page.getByRole('textbox',{name:'负责人',exact:true}).fill('审核人');await page.keyboard.press('Escape');await page.getByRole('dialog').waitFor({state:'hidden'});await button('加入待办').first().click();assert.equal(await page.getByRole('textbox',{name:'待办事项',exact:true}).inputValue(),'验证后更新产品方案');await button('确认加入').click();await expectText(page.locator('main'),'验证后更新产品方案');await visible(button('已加入 · 演示'));
 });
 await test('Daily Ask AI scopes history and drafts by date, citations, cancel and backup boundaries', async () => {
  await button('重置原型').click();await nav('每日记录');
  assert.equal(await page.getByRole('navigation').getByRole('button',{name:'知识库',exact:true}).count(),0);
  const input=page.getByRole('textbox',{name:'向 Ask AI 提问',exact:true});
  await input.fill('日期草稿');await button('关闭 Ask AI').click();await button('Ask AI').click();assert.equal(await input.inputValue(),'日期草稿');
  await button('11月11日 · 已备份').click();assert.equal(await input.inputValue(),'');await input.fill('另一日草稿');
  await button('11月12日 · 已备份').click();assert.equal(await input.inputValue(),'日期草稿');
  await button('总结这一天的记录').click();await page.getByTestId('chat-messages').getByRole('button').first().waitFor();
  await expectText(page.getByTestId('chat-messages'),'让想法有一个可以回来的地方');
  assert(!(await page.getByTestId('chat-messages').innerText()).includes('周末的阅读计划'));
  await page.getByTestId('chat-messages').getByRole('button').first().click();
  await page.waitForFunction(()=>document.activeElement?.id==='daily-2026-11-12-08:42');await visible(button('收起内容'));
  await button('11月11日 · 已备份').click();assert.equal(await input.inputValue(),'另一日草稿');assert.equal(await page.getByTestId('chat-messages').locator('article').count(),0);
  await button('发送问题').click();await button('11月12日 · 已备份').click();await sleep(900);await button('11月11日 · 已备份').click();assert.equal(await page.getByTestId('chat-messages').locator('article').count(),1);
  await button('总结这一天的记录').click();await page.getByTestId('chat-messages').getByRole('button').first().waitFor();await expectText(page.getByTestId('chat-messages'),'周末的阅读计划');
  await button('11月13日 · 待备份').click();assert(await input.isDisabled());assert(await button('总结这一天的记录').isDisabled());await expectText(page.getByTestId('chat-messages'),'这一天尚未备份');
  await button('11月12日 · 已备份').click();await select('演示设备状态','离线');await button('总结这一天的记录').click();await button('停止生成').click();await sleep(900);assert.equal(await button('停止生成').count(),0);
  await nav('模型库');await button('卸载模型').click();await nav('每日记录');await input.fill('没有模型');assert(await button('发送问题').isDisabled());
  await page.evaluate(()=>location.hash='knowledge');await page.locator('main[data-page="meetings"]').waitFor();await button('重置原型').click();
 });
 await test('Models distinguish download/load/unload/delete; ASR and pairing', async () => {
  await nav('模型库');await button('下载模型').click();await button('取消').click();await button('下载模型').click();await button('加载模型').waitFor();await button('加载模型').click();await sleep(2700);
  const cards=page.locator('main section');await cards.filter({hasText:'Qwen3-1.7B'}).getByRole('button',{name:'卸载模型',exact:true}).click();await cards.filter({hasText:'Qwen3-1.7B'}).getByRole('button',{name:'删除',exact:true}).click();await button('确认删除').click();await visible(button('下载模型'));
  await page.getByRole('tab',{name:'ASR 语音转写',exact:true}).click();await button('下载模型').click();await button('加载模型').waitFor();await button('加载模型').click();await sleep(2700);await button('模拟 iPhone 转写请求').click();await expectText(page.locator('main'),'示例转写已返回');
  await nav('概览');await button('配对 iPhone').click();await button('模拟失效').click();assert(await button('模拟扫码成功').isDisabled());await button('重新生成').click();await button('模拟扫码成功').click();await button('撤销').last().click();await button('确认撤销').click();
 });
 await test('Settings hierarchy and directory change update every storage location', async () => {
  await page.setViewportSize({width:1600,height:1000});await button('重置原型').click();await nav('设置');if(await button('展开菜单').count()) await button('展开菜单').click();
  await visible(page.getByRole('navigation').getByRole('button',{name:'主目录设置',exact:true}));
  await visible(page.getByRole('navigation').getByRole('button',{name:'隐私与说明',exact:true}));
  await page.getByRole('group',{name:'设置分类'}).getByRole('button',{name:'隐私与说明'}).click();
  await visible(page.getByRole('heading',{name:'数据边界，看得见，也由你掌握。'}));
  await page.getByRole('group',{name:'设置分类'}).getByRole('button',{name:'主目录设置'}).click();
  await button('更改主目录').click();await page.getByRole('textbox',{name:'新的主目录'}).fill('relative/path');assert(await button('迁移并使用新目录').isDisabled());
  await page.getByRole('dialog').getByRole('button',{name:'取消',exact:true}).click();assert.equal(await page.getByTestId('root-path').innerText(),'~/Documents/EurekaLife');
  await button('更改主目录').click();await button('外置磁盘（示例）').click();await button('迁移并使用新目录').click();
  await page.getByRole('dialog',{name:'更改主目录'}).waitFor({state:'hidden'});assert.equal(await page.getByTestId('root-path').innerText(),'/Volumes/Archive/EurekaLife');
  await page.screenshot({path:path.join(out,'settings-1440.png')});
  await nav('模型库');await visible(page.getByText('模型位置：/Volumes/Archive/EurekaLife/Models',{exact:true}));
  await nav('会议');await visible(page.getByText('会议文件位置：/Volumes/Archive/EurekaLife/Meetings',{exact:true}));
  await nav('每日记录');assert.equal(await page.getByTestId('backup-path').innerText(),'/Volumes/Archive/EurekaLife/DailyRecords/iPhone');
 });
 await test('Meeting deletion cancels safely, confirms once and blocks live recording', async () => {
  await button('重置原型').click();await nav('会议');
  const title='Mac 会议录制 · 产品评审';const row=page.getByRole('row').filter({hasText:title});
  await row.getByRole('button',{name:'删除会议 '+title,exact:true}).click();await page.getByRole('dialog').getByRole('button',{name:'取消',exact:true}).click();await visible(row);
  await row.getByRole('button',{name:'删除会议 '+title,exact:true}).click();await page.getByRole('dialog').getByRole('button',{name:'删除会议',exact:true}).click();await row.waitFor({state:'detached'});
  await page.getByTestId('meeting-entries').getByRole('button',{name:/即时录音/}).click();await page.getByRole('textbox',{name:'会议名称',exact:true}).fill('不可删除的录制');await button('开始录制').click();await button('我的会议').click();
  assert(await button('删除会议 不可删除的录制').isDisabled());
  await nav('设置');assert(await button('更改主目录').isDisabled());
  await button('重置原型').click();await nav('会议');await visible(page.getByRole('row').filter({hasText:title}));
 });
 await test('Daily backups browse offline, retain state across routes and reset', async () => {
  await nav('每日记录');assert.equal(await button('Ask AI').count(),1);
  await button('11月13日 · 待备份').click();await visible(page.getByRole('heading',{name:'这一天，还没有备份到 Mac'}));
  await page.getByRole('textbox',{name:'演示设备状态'}).click();await page.getByRole('option',{name:'离线',exact:true}).click();assert(await button('备份最新数据').isDisabled());
  await button('11月12日 · 已备份').click();await visible(page.getByRole('heading',{name:'上午的产品讨论'}));await button('查看内容').first().click();await visible(button('收起内容'));
  await page.getByRole('textbox',{name:'演示设备状态'}).click();await page.getByRole('option',{name:'已连接',exact:true}).click();await button('备份最新数据').click();
  await visible(button('备份已是最新'));assert.equal(await button('11月13日 · 已备份').getAttribute('aria-pressed'),'true');
  await page.screenshot({path:path.join(out,'daily-1440.png')});await nav('会议');await nav('每日记录');await visible(button('备份已是最新'));
  await button('重置原型').click();await visible(button('11月13日 · 待备份'));
  await button('备份最新数据').click();await page.getByRole('textbox',{name:'全局演示状态'}).click();await page.getByRole('option',{name:'网络不可达',exact:true}).click();await nav('每日记录');await sleep(1300);
  await visible(button('11月13日 · 待备份'));assert(await button('备份最新数据').isDisabled());await visible(button('11月12日 · 已备份'));
  await page.getByRole('textbox',{name:'全局演示状态'}).click();await page.getByRole('option',{name:'日常使用',exact:true}).click();await button('重置原型').click();
 });
 await test('Responsive six-route layout, mobile navigation and modal focus', async () => {
  await button('重置原型').click();
  for(const width of [1600,1280,1024,768,390,320]) {
   await page.setViewportSize({width,height:1000});
   for(const route of ['meetings','overview','models','settings','privacy','daily']) {
    await page.evaluate(route=>location.hash=route,route);await page.locator(`main[data-page="${route}"]`).waitFor();await sleep(60);
    assert.equal(await button('Ask AI').count(),['meetings','daily'].includes(route)?1:0);
    if(!['meetings','daily'].includes(route)) assert.equal(await page.getByRole('complementary',{name:'Ask AI',exact:true}).count(),0);
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),`${width}/${route}: document overflow`);
    if(route === 'daily') { const backupButton=page.getByRole('button',{name:'备份最新数据',exact:true});if(await backupButton.count()) assert(await backupButton.evaluate(e => { const label=e.querySelector('.mantine-Button-label'); return !label || label.scrollWidth <= label.clientWidth + 1; }),`${width}: backup action text clipped`); }
    if(['settings','daily'].includes(route) && [1600,390].includes(width)) await page.screenshot({path:path.join(out,`${route}-${width}.png`)});
   }
   await page.evaluate(()=>location.hash='meetings');await page.locator('main[data-page="meetings"]').waitFor();await sleep(200);await page.screenshot({path:path.join(out,`meetings-${width}.png`)});
  }
  await button('显示菜单').click();await page.getByRole('dialog',{name:'导航',exact:true}).waitFor();await page.getByRole('dialog').getByRole('button',{name:'每日记录',exact:true}).click();await page.getByRole('dialog').waitFor({state:'hidden'});
  await button('Ask AI').click();await page.getByRole('dialog',{name:'Ask AI',exact:true}).waitFor();await page.getByRole('dialog').getByRole('textbox',{name:'向 Ask AI 提问'}).fill('窄屏草稿');await page.keyboard.press('Escape');await page.getByRole('dialog').waitFor({state:'hidden'});await sleep(250);assert(await button('Ask AI').evaluate(e=>e===document.activeElement));await button('Ask AI').click();assert.equal(await page.getByRole('dialog').getByRole('textbox',{name:'向 Ask AI 提问'}).inputValue(),'窄屏草稿');await page.getByRole('dialog').getByRole('button',{name:'总结这一天的记录',exact:true}).click();await page.getByRole('dialog').getByTestId('chat-messages').getByRole('button').first().waitFor();await page.getByRole('dialog').getByTestId('chat-messages').getByRole('button').first().click();await page.getByRole('dialog').waitFor({state:'hidden'});await sleep(300);assert.equal(await page.locator('section[id="daily-2026-11-12-08:42"]').evaluate(e=>e===document.activeElement),true);
 });
 await test('No browser errors, missing resources, external requests or network writes',async()=>{assert.deepEqual(errors,[]);assert.deepEqual(failures,[]);assert.deepEqual(network,[]);});
 } catch(e) { console.error(e);await page.screenshot({path:path.join(out,'failure.png'),fullPage:true});console.error((await page.locator('body').innerText()).slice(-4500));process.exitCode=1; }
 finally { fs.writeFileSync(path.join(__dirname,'results-daily-ai-2026-11-13.json'),JSON.stringify({date:new Date().toISOString(),browser:await browser.version(),source:'uncommitted working tree',results,errors,failures,network,limitations:['Synthetic frontend only','No native build/device/real AI acceptance','Real Chinese IME and physical touch not tested']},null,2)+'\n');await browser.close(); }
})();
