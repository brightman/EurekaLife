// Run with PLAYWRIGHT_MODULE pointing at an existing Playwright install.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const origin = process.env.WISELIFE_MAC_PREVIEW || 'http://127.0.0.1:8791';
const out = __dirname;

(async () => {
  const browser = await chromium.launch();
  const errors = [], failedRequests = [], checks = [];
  try {
    const page = await browser.newPage({ viewport: { width: 1500, height: 1040 }, reducedMotion: 'reduce' });
    page.on('pageerror', error => errors.push(error.message));
    page.on('response', response => { if (response.status() >= 400) failedRequests.push(response.url()); });
    page.on('request', request => {
      assert.equal(request.method(), 'GET');
      assert(request.url().startsWith(origin), 'Prototype must not contact external services');
    });
    await page.goto(origin + '/#overview', { waitUntil: 'networkidle' });
    const hardware = page.locator('.hardware-overview');
    assert.equal(await page.locator('.metrics').count(), 1);
    assert.equal(await hardware.locator('.metrics').count(), 1);
    for (const text of ['MacBook Air · Apple M3', '16 GB', '512 GB', '128 GB', '运行状态']) {
      assert((await hardware.innerText()).includes(text));
    }
    const bounds = await hardware.boundingBox();
    assert(bounds.y + bounds.height < 1040, 'Merged device card fits in the desktop viewport');
    await page.locator('[data-action=request]').click();
    assert.equal(await page.locator('.hardware-status').innerText(), '正在推理');
    await page.waitForFunction(() => document.querySelector('.hardware-runtime').textContent.includes('0.82 s'));
    assert.equal(await page.locator('.hardware-status').innerText(), '模型已就绪');
    for (const [scenario, status] of [['network', '网络不可达'], ['pressure', '内存压力偏高'], ['first', '服务已暂停']]) {
      await page.locator('#scenario').selectOption(scenario);
      assert.equal(await page.locator('.hardware-status').innerText(), status);
    }
    await page.locator('#scenario').selectOption('ready');
    await page.locator('[data-action=service]').click();
    assert.equal(await page.locator('.hardware-status').innerText(), '服务已暂停');
    assert(await page.locator('[data-action=request]').isDisabled());
    await page.locator('[data-action=service]').click();
    await page.locator('.window').screenshot({ path: path.join(out, 'overview.png') });
    checks.push('One merged hardware/runtime block, dimensions, request progress, paused/offline/pressure states');

    await page.locator('#navigation [data-page=knowledge]').click();
    await page.locator('#kb-question').fill('保留这条草稿');
    const expandedWidth = (await page.locator('.kb-records').boundingBox()).width;
    await page.locator('[data-kb=collapse-ai]').click();
    assert(await page.locator('#kb-ai-panel').isHidden());
    assert.equal(await page.locator('[data-kb=toggle-ai]').getAttribute('aria-expanded'), 'false');
    assert((await page.locator('.kb-records').boundingBox()).width > expandedWidth + 300);
    await page.locator('.window').screenshot({ path: path.join(out, 'knowledge-collapsed.png') });
    await page.locator('[data-kb=toggle-ai]').press('Enter');
    assert.equal(await page.locator('#kb-question').inputValue(), '保留这条草稿');
    await page.locator('[data-prompt]').first().click();
    await page.locator('[data-kb=collapse-ai]').click();
    await page.waitForFunction(() => document.querySelectorAll('.kb-message.assistant').length === 1);
    assert(await page.locator('#kb-ai-panel').isHidden());
    await page.locator('[data-kb=toggle-ai]').click();
    assert((await page.locator('.kb-message.assistant').innerText()).includes('示例回答'));
    await page.locator('[data-kb=collapse-ai]').click();
    await page.locator('[data-record=meeting]').click();
    await page.locator('[data-ask=meeting]').click();
    assert(await page.locator('#kb-ai-panel').isVisible());
    assert((await page.locator('.kb-scope').innerText()).includes('知识库与本地 AI'));
    await page.locator('#kb-question').fill('切页期间保留的问题');
    await page.locator('#navigation [data-page=overview]').click();
    await page.locator('#navigation [data-page=knowledge]').click();
    assert.equal(await page.locator('#kb-question').inputValue(), '切页期间保留的问题');
    checks.push('Ask AI expands records, keyboard toggles, preserves draft/history/pending response, record-scoped ask opens panel');

    // A reply must not redraw the persistent #main host after leaving Knowledge.
    await page.locator('[data-kb=clear]').click();
    await page.locator('[data-prompt]').first().click();
    await page.locator('#navigation [data-page=overview]').click();
    await page.waitForTimeout(1000);
    assert(await hardware.isVisible());
    assert.equal(await page.locator('.kb-layout').count(), 0);
    await page.locator('#navigation [data-page=knowledge]').click();
    assert.equal(await page.locator('.kb-message.assistant').count(), 1);
    checks.push('Pending knowledge response does not replace Overview after navigation');

    await page.locator('[data-kb=calendar]').click();
    await page.locator('[data-date="2026-10-30"]').click();
    await page.locator('[data-kind=健康]').click();
    await page.locator('#kb-search').fill('无匹配记录');
    await page.locator('[data-kb=start-recording]').click();
    assert.equal((await page.locator('.kb-date-trigger').innerText()).replace(/\s+/g, ' '), '2026.10.31 ⌄');
    assert.equal(await page.locator('#kb-search').inputValue(), '');
    assert(await page.locator('[data-kb=start-recording]').isDisabled());
    await page.waitForFunction(() => document.querySelector('[data-recording-clock]').textContent >= '00:00:02');
    await page.locator('[data-kb=collapse-ai]').click();
    await page.locator('.window').screenshot({ path: path.join(out, 'knowledge-recording.png') });
    await page.locator('#navigation [data-page=overview]').click();
    await page.locator('#navigation [data-page=knowledge]').click();
    assert(await page.locator('.kb-recording-bar').isVisible());
    await page.locator('[data-kb=stop-recording]').click();
    const captured = page.locator('[id^="kb-record-mac-capture-"]');
    assert.equal(await captured.count(), 1);
    assert((await captured.innerText()).includes('这台 Mac'));
    assert((await captured.innerText()).includes('没有使用麦克风'));
    assert(parseInt(await captured.locator('.kb-meta span').last().innerText(), 10) > 0);
    assert.equal(await page.locator('.kb-recording-bar').count(), 0);
    assert(await page.locator('[data-kb=start-recording]').isEnabled());
    await page.locator('[data-ask="mac-capture-1"]').click();
    assert(await page.locator('#kb-ai-panel').isVisible());
    await page.locator('#kb-question').fill('这条录音的内容是什么？');
    await page.locator('#kb-form button[type=submit]').click();
    await page.waitForFunction(() => !document.querySelector('.kb-thinking'));
    assert((await page.locator('.kb-message.assistant').last().innerText()).includes('未生成音频或转写'));
    await page.locator('.window').screenshot({ path: path.join(out, 'knowledge-saved.png') });
    await page.locator('#reset').click();
    await page.locator('#navigation [data-page=knowledge]').click();
    assert.equal(await captured.count(), 0);
    assert.equal(await page.locator('.kb-message').count(), 0);
    await page.locator('[data-kb=start-recording]').click();
    await page.locator('#reset').click();
    await page.locator('#navigation [data-page=knowledge]').click();
    assert.equal(await page.locator('.kb-recording-bar').count(), 0);
    assert(await page.locator('[data-kb=start-recording]').isEnabled());
    checks.push('Recording starts once, ticks, survives navigation, stops into one Mac demo record, supports scoped ask and resets');

    for (const width of [1500, 1280, 1024, 900, 768, 390, 320]) {
      await page.setViewportSize({ width, height: 1040 });
      for (const view of ['overview', 'knowledge']) {
        await page.locator(`#navigation [data-page=${view}]`).click();
        assert(!await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), `${view} overflow at ${width}`);
      }
      if (width === 1500 || width === 390) {
        await page.locator('.window').screenshot({ path: path.join(out, `knowledge-${width}.png`) });
      }
      await page.locator('[data-kb=collapse-ai]').click();
      assert(!await page.evaluate(() => document.documentElement.scrollWidth > innerWidth));
      await page.locator('[data-kb=toggle-ai]').click();
    }
    await page.reload({ waitUntil: 'networkidle' });
    assert.equal(await page.evaluate(() => localStorage.length + sessionStorage.length), 0);
    assert.deepEqual(errors, []);
    assert.deepEqual(failedRequests, []);
    checks.push('320–1500px overview and expanded/collapsed knowledge layouts; no JS errors, failed assets, external requests or storage');
    const report = { status: 'PASS', time: new Date().toISOString(), origin, checks, errors, failedRequests,
      boundary: 'HTML prototype only. Recording, hardware values and AI responses are demonstrations; no microphone or native App used.' };
    fs.writeFileSync(path.join(out, 'results.json'), JSON.stringify(report, null, 2) + '\n');
    console.log(JSON.stringify(report, null, 2));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
