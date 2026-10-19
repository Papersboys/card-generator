'use strict';
const english = {
  skip:'Skip to content',navPreview:'Preview',navHow:'How it works',navFaq:'FAQ',eyebrow:'MADE FOR macOS · FREE & OPEN SOURCE',heroLine1:'Your virtual Visa.',heroLine2:'Right at home on Mac.',heroDescription:'Card number, CVC, expiration, and billing address—ready to view and copy after approval. Bring everyday Link virtual-card tasks into one native menu bar app.',download:'Download for Mac',guide:'Read the guide',requirements:'Apple Silicon · macOS 13+ · No Node.js or CLI needed',metaNative:'Native Mac app',metaLanguage:'English & Chinese',metaUpdate:'In-app updates',approved:'Approved',virtualCard:'VIRTUAL PAYMENT CARD',expires:'EXPIRES',demo:'DEMO ONLY',billing:'Billing address',copyDemo:'Try copying the demo number',visualCaption:'Feature illustration · Fictional details, not usable for payment',fundingTitle:'Amex → Visa, with less friction.',fundingDescription:'Choose an Amex saved in Link as the funding method and request a Visa virtual card for checkout. Availability depends on Link account eligibility, the payment method, and merchant restrictions.',previewEyebrow:'START WITH THE CARD DETAILS',previewTitle:'The details you need, all together.',previewDescription:'The actual app. Create, approve, and view—then find your requests again whenever you need them.',tabCard:'Card details',tabCreate:'Create',tabApprove:'Approve',tabUpdate:'Updates',screenshotNote:'Screenshots use sample accounts and fictional card details; some show earlier versions. Actual card details are determined by Link.',featuresEyebrow:'THE APP HANDLES THE STEPS. YOU STAY IN CONTROL.',featuresTitle:'Less back and forth. More getting done.',feature1Title:'Fill in the purchase. Context writes itself.',feature1Description:'Choose a payment method, enter the merchant, item, and amount, and review the automatically generated context before submitting.',feature2Title:'Every request gets your approval.',feature2Description:'Review requests in the Approve tab and follow the link to confirm in Link. Card details refresh after approval.',feature3Title:'Feels familiar. Because it is.',feature3Description:'Open it from the menu bar. Switch between English and Chinese, resize the window, and use familiar copy and paste shortcuts.',feature4Title:'Credentials stay on your Mac.',feature4Description:'The app connects directly to Link. Login credentials go in Keychain; card details stay in memory and clear when the window closes.',howEyebrow:'FROM REQUEST TO CHECKOUT',howTitle:'Three steps to your card details.',step1Title:'Create a request',step1Description:'Sign in to Link, select a funding method, and enter the merchant and actual checkout amount. USD uses cents: 1500 = $15.',step2Title:'Approve it in Link',step2Description:'Follow the approval link, review the request, and confirm it yourself. Find earlier requests in the Approve tab.',step3Title:'Copy the details into checkout',step3Description:'Return to the app for the card number, CVC, expiration, and billing address. Copy them into the merchant’s payment form.',faqTitle:'A few things before you download.',faq1Q:'Which Macs are supported? Any extra tools?',faq1A:'Apple Silicon Macs (M-series chips) running macOS 13 or later. Download the ZIP, extract it, and drag LinkCard.app to Applications. No Node.js, npm, or link-cli installation required.',faq2Q:'What if macOS blocks the first launch?',faq2A:'Current builds are ad-hoc signed and not Apple notarized. After confirming the download came from this project’s GitHub Release, try opening the app, then go to System Settings → Privacy & Security and choose Open Anyway.',faq3Q:'Can it update itself?',faq3A:'From v2.6.0, it checks daily by default and also offers manual checks. Confirm an available update to download, install, and relaunch. Both the update feed and archive are signature-verified. Older versions need one manual upgrade.',faq4Q:'Which currencies are supported?',faq4A:'The default is USD, entered in cents, with a minimum of 50 ($0.50). Other currencies use three-letter codes and their own minor units. Link has not published a complete list; availability is determined by its API. The app does not convert currencies.',faq5Q:'Is this an official Link app? Where do my details go?',faq5A:'This is an independent open-source project, not affiliated with Link or Stripe. The app connects directly to Link, without a developer-operated server. Login credentials stay in your Mac’s Keychain; card details are displayed in memory. Log out at any time to clear the app’s credentials.',bottomTitle:'Your next checkout starts here.',bottomDescription:'Free and open source. Link virtual cards, in your menu bar.',bottomRequirements:'Apple Silicon · macOS 13+',footerNote:'Independent open-source project · Not affiliated with Link or Stripe',guideShort:'Guide'
};
const nodes = [...document.querySelectorAll('[data-i18n]')];
const chinese = Object.fromEntries(nodes.map(node => [node.dataset.i18n, node.textContent]));
const screenshots = {
  card:['images/card-details-zh.jpg','虚构 Visa 卡详情：卡号、CVC、有效期及账单地址','Fictional Visa card details: number, CVC, expiration, and billing address'],
  create:['images/create-en.jpg','创建请求：填写商家、金额和商品，自动生成用途','Create request: merchant, amount, item, and generated context'],
  approve:['images/approve-zh.jpg','待批准请求与 Link 批准链接','Pending requests with a Link approval link; Chinese interface'],
  update:['images/update-controls-zh.jpg','自动更新开关与检查更新入口','Automatic update toggle and manual update check; Chinese interface']
};
let language='zh';
let currentShot='card';
let toastTimer;
function setShot(key, focus=false) {
  if (!screenshots[key]) return;
  currentShot=key;
  const [src,zh,en]=screenshots[key];
  const image=document.getElementById('app-screenshot');
  image.src=src; image.alt=language==='en'?en:zh;
  document.querySelectorAll('[data-shot]').forEach(tab=>{
    const active=tab.dataset.shot===key;
    tab.setAttribute('aria-selected',String(active)); tab.tabIndex=active?0:-1;
    if (active && focus) tab.focus();
  });
  document.getElementById('screenshot-panel').setAttribute('aria-labelledby',`tab-${key}`);
}
function setLanguage(lang) {
  language=lang==='en'?'en':'zh';
  document.documentElement.lang=language==='en'?'en':'zh-CN';
  const messages=language==='en'?english:chinese;
  nodes.forEach(node=>{node.textContent=messages[node.dataset.i18n]||chinese[node.dataset.i18n];});
  document.querySelectorAll('[data-lang]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.lang===language)));
  document.querySelectorAll('.guide-link').forEach(link=>{link.href=language==='en'?'guide.en.html':'guide.html';});
  document.title=language==='en'?'Link Card — Visa virtual cards, at home on your Mac':'Link Card — 在 Mac 上轻松管理 Visa 虚拟卡';
  document.querySelector('meta[name="description"]').content=language==='en'?english.heroDescription:chinese.heroDescription;
  try {localStorage.setItem('link-card-language',language);} catch {}
  setShot(currentShot);
}
document.querySelectorAll('[data-lang]').forEach(button=>button.addEventListener('click',()=>setLanguage(button.dataset.lang)));
const tabs=[...document.querySelectorAll('[data-shot]')];
tabs.forEach((tab,index)=>{
  tab.addEventListener('click',()=>setShot(tab.dataset.shot));
  tab.addEventListener('keydown',event=>{
    let next;
    if(event.key==='ArrowRight') next=(index+1)%tabs.length;
    if(event.key==='ArrowLeft') next=(index+tabs.length-1)%tabs.length;
    if(event.key==='Home') next=0;
    if(event.key==='End') next=tabs.length-1;
    if(next!==undefined){event.preventDefault();setShot(tabs[next].dataset.shot,true);}
  });
});
document.getElementById('copy-demo').addEventListener('click',async()=>{
  let message;
  try {
    await navigator.clipboard.writeText('4242 4242 4242 4242');
    message=language==='en'?'Demo number copied. Not usable for payment.':'已复制演示卡号，不能用于真实付款。';
  } catch {message=language==='en'?'Demo number: 4242 4242 4242 4242':'演示卡号：4242 4242 4242 4242';}
  const toast=document.getElementById('toast');toast.textContent=message;toast.classList.add('visible');
  clearTimeout(toastTimer);toastTimer=setTimeout(()=>toast.classList.remove('visible'),3500);
});
let initial='zh';
try {initial=new URLSearchParams(location.search).get('lang')||localStorage.getItem('link-card-language')||'zh';} catch {}
setLanguage(initial);
