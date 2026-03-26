const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ 
    headless: false,
    executablePath: 'C:\\Program Files\\BraveSoftware\\Brave-Browser\\Application\\brave.exe'
  });
  const page = await browser.newPage();
  
  // 打开百度
  await page.goto('https://www.baidu.com');
  console.log('✓ 百度已打开');
  console.log('标题:', await page.title());
  
  // 获取输入框并搜索
  await page.fill('#kw', 'OpenAI GPT-5');
  await page.click('#su');
  console.log('✓ 已搜索: OpenAI GPT-5');
  
  // 等待结果页面
  await page.waitForLoadState('networkidle');
  console.log('标题:', await page.title());
  
  // 截图
  await page.screenshot({ path: 'baidu-result.png' });
  console.log('✓ 已截图: baidu-result.png');
  
  await browser.close();
})();
