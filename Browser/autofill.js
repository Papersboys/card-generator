/* Runs only after a user action. Returns field names/counts, never field values. */
(function linkCardAutofill(command) {
  'use strict';
  const here = new URL(location.href);
  if (here.protocol !== 'https:' || here.username || here.password) return {error:'https_required'};
  if (command.action === 'fill' && command.url !== here.href) return {error:'page_changed'};
  const fields = [], seen = new Set(); let blockedFrames = 0;
  function classify(el) {
    const ac = (el.getAttribute('autocomplete') || '').toLowerCase().split(/\s+/);
    const card = {'cc-number':'number','cc-csc':'cvc','cc-exp':'expiry','cc-exp-month':'month','cc-exp-year':'year','cc-name':'name'};
    for (const token of ac) if (card[token]) return card[token];
    if (ac.includes('shipping')) return null;
    const address = {'name':'name','street-address':'street','address-line1':'line1','address-line2':'line2','address-level2':'city','address-level1':'state','postal-code':'postal','country':'country','country-name':'country'};
    if (ac.includes('billing')) for (const token of ac) if (address[token]) return address[token];
    const key = [el.id,el.name,el.getAttribute('data-field'),el.getAttribute('placeholder'),el.getAttribute('aria-label')].filter(Boolean).join(' ').toLowerCase().replace(/[_-]+/g,' ');
    if (/\b(card number|cardnumber|ccnumber|cc number|credit card number)\b/.test(key)) return 'number';
    if (/\b(cvc|cvv|cvv2|csc|security code|card security code)\b/.test(key)) return 'cvc';
    if (/\b(expiry month|expiration month|exp month|ccmonth)\b/.test(key)) return 'month';
    if (/\b(expiry year|expiration year|exp year|ccyear)\b/.test(key)) return 'year';
    if (/\b(expiry|expiration|expiration date|expiry date|mm\s*\/\s*yy(?:yy)?)\b/.test(key)) return 'expiry';
    if (/\b(cardholder|card holder|name on card)\b/.test(key)) return 'name';
    if (/\bbilling\b/.test(key)) {
      if (/\b(zip|postal)\b/.test(key)) return 'postal';
      if (/\bcity\b/.test(key)) return 'city';
      if (/\b(state|province)\b/.test(key)) return 'state';
      if (/\bcountry\b/.test(key)) return 'country';
      if (/\b(address2|address 2|line2|line 2)\b/.test(key)) return 'line2';
      if (/\b(address|address1|line1|line 1)\b/.test(key)) return 'line1';
    }
    return null;
  }
  function visit(doc) {
    if (seen.has(doc)) return; seen.add(doc);
    for (const el of doc.querySelectorAll('input,select,textarea')) {
      if (el.disabled || el.readOnly || ['hidden','submit','button','checkbox','radio','password'].includes(el.type)) continue;
      const view=doc.defaultView, style=view.getComputedStyle(el);
      if (!el.getClientRects().length || style.visibility==='hidden' || style.display==='none') continue;
      const kind=classify(el); if (kind) fields.push({el,kind});
    }
    for (const frame of doc.querySelectorAll('iframe,frame')) {
      try {
        const child=frame.contentDocument;
        if (!child || child.location.origin!==here.origin) {blockedFrames++;continue;}
        visit(child);
      } catch {blockedFrames++;}
    }
  }
  visit(document);
  const kinds=[...new Set(fields.map(f=>f.kind))];
  if (command.action==='scan') return {url:here.href,origin:here.origin,kinds,blockedFrames};
  if (command.action!=='fill') return {error:'invalid_action'};
  if (!fields.some(f=>f.kind==='number')) return {error:'no_card_fields',blockedFrames};
  const p=command.card;
  if (!p || !/^\d{12,19}$/.test(p.number || '') || !/^\d{3,4}$/.test(p.cvc || '') || !/^(0[1-9]|1[0-2])$/.test(p.month || '') || !/^\d{4}$/.test(p.year || '')) return {error:'invalid_card'};
  const values={...p,expiry:p.month+'/'+p.year.slice(-2),street:[p.line1,p.line2].filter(Boolean).join('\n')};
  const filled=[],skipped=[];
  for (const {el,kind} of fields) {
    if (location.href!==command.url || el.ownerDocument.location.origin!==here.origin) return {error:'page_changed'};
    let value=values[kind]; if (!value) {skipped.push(kind);continue;}
    if (kind==='expiry' && el.type==='month') value=p.year+'-'+p.month;
    else if (kind==='expiry' && Number(el.maxLength)>=7) value=p.month+'/'+p.year;
    else if (kind==='year' && el.maxLength===2) value=p.year.slice(-2);
    const view=el.ownerDocument.defaultView;
    if (el.tagName==='SELECT') {
      const candidates=[value];
      if (kind==='month') candidates.push(String(Number(p.month)));
      if (kind==='year') candidates.push(p.year,p.year.slice(-2));
      const option=Array.from(el.options).find(o=>!o.disabled && candidates.some(c=>String(o.value).toLowerCase()===c.toLowerCase() || o.text.trim().toLowerCase()===c.toLowerCase()));
      if (!option) {skipped.push(kind);continue;} value=option.value;
    }
    const prototype=el.tagName==='SELECT' ? view.HTMLSelectElement.prototype : el.tagName==='TEXTAREA' ? view.HTMLTextAreaElement.prototype : view.HTMLInputElement.prototype;
    const setter=Object.getOwnPropertyDescriptor(prototype,'value')?.set;
    if (!setter) {skipped.push(kind);continue;}
    setter.call(el,value);
    el.dispatchEvent(new view.Event('input',{bubbles:true}));
    el.dispatchEvent(new view.Event('change',{bubbles:true}));
    filled.push(kind);
  }
  return {filled:[...new Set(filled)],skipped:[...new Set(skipped)],blockedFrames};
})
