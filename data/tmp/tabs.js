// JavaScript that runs in browser to get all open CNBC quote tab titles
async () => {
  const targets = await chrome.targets ? chrome.targets() : [];
  return targets.map(t => ({type: t.type, url: t.url, title: t.title})).filter(t => t.url && t.url.includes('cnbc.com/quotes'));
}
