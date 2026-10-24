const fs=require('node:fs');const vm=require('node:vm');const assert=require('node:assert/strict');
const engine=fs.readFileSync(__dirname+'/autofill.js','utf8');
class Field {
  constructor(kind,attrs={}) {this.attrs={autocomplete:kind,...attrs};this.type='text';this.tagName='INPUT';this.maxLength=-1;this.id='';this.name='';this.events=[];this._value='';}
  get value(){return this._value} set value(v){this._value=v}
  getAttribute(k){return this.attrs[k] || null} getClientRects(){return this.hidden ? [] : [{}]}
  dispatchEvent(e){this.events.push(e.type)}
}
class Select extends Field {constructor(kind,options){super(kind);this.tagName='SELECT';this.type='select-one';this.options=options;}}
Object.defineProperty(Select.prototype,'value',Object.getOwnPropertyDescriptor(Field.prototype,'value'));
function page(fields,url='https://shop.example/checkout',frames=[]) {
 const location=new URL(url),doc={location,querySelectorAll(q){return q==='input,select,textarea' ? fields : frames},defaultView:{HTMLInputElement:Field,HTMLSelectElement:Select,HTMLTextAreaElement:Field,Event:class {constructor(type){this.type=type}},getComputedStyle(){return {visibility:'visible',display:'block'}}}};
 fields.forEach(f=>f.ownerDocument=doc);return {location,document:doc};
}
function run(env,command){return vm.runInNewContext('('+engine+')(command)',{...env,URL,command});}
const card={number:'4242424242424242',cvc:'123',month:'03',year:'2030',line1:'123 Test St',postal:'98000'};
const pan=new Field('cc-number'),cvc=new Field('cc-csc'),expiry=new Field('cc-exp'),postal=new Field('billing postal-code'),shipping=new Field('shipping postal-code'),unknown=new Field('',{'placeholder':'Account number'}),hidden=new Field('cc-number');hidden.hidden=true;
const env=page([pan,cvc,expiry,postal,shipping,unknown,hidden]);
const scanned=run(env,{action:'scan'});assert(scanned.kinds.includes('number'));assert(!JSON.stringify(scanned).includes('424242'));assert.equal(pan.value,'');
let result=run(env,{action:'fill',url:env.location.href,card});assert(result.filled.includes('number'));assert.equal(pan.value,card.number);assert.equal(cvc.value,'123');assert.equal(expiry.value,'03/30');assert.equal(postal.value,'98000');assert.equal(shipping.value,'');assert.equal(unknown.value,'');assert.equal(hidden.value,'');assert.equal(pan.events.join(','),'input,change');
assert(!JSON.stringify(result).includes(card.number));assert(!JSON.stringify(result).includes('123 Test St'));
const changedPan=new Field('cc-number'),changed=page([changedPan]);assert.equal(run(changed,{action:'fill',url:'https://other.example/checkout',card}).error,'page_changed');assert.equal(changedPan.value,'');
assert.equal(run(page([new Field('cc-number')],'http://shop.example/checkout'),{action:'scan'}).error,'https_required');
assert.equal(run(page([new Field('cc-number')],'https://user:secret@shop.example/checkout'),{action:'scan'}).error,'https_required');
const year=new Select('cc-exp-year',[{value:'30',text:'2030'}]),month=new Select('cc-exp-month',[{value:'3',text:'March'}]),pan2=new Field('cc-number'),env2=page([pan2,month,year]);run(env2,{action:'fill',url:env2.location.href,card});assert.equal(month.value,'3');assert.equal(year.value,'30');
const childField=new Field('cc-csc'),child=page([childField]);const frameEnv=page([new Field('cc-number')],undefined,[{contentDocument:child.document},{get contentDocument(){throw Error('cross origin')}}]);
result=run(frameEnv,{action:'fill',url:frameEnv.location.href,card});assert.equal(childField.value,'123');assert.equal(result.blockedFrames,1);
const noCardField=new Field('billing postal-code'),noCardEnv=page([noCardField]);assert.equal(run(noCardEnv,{action:'fill',url:noCardEnv.location.href,card}).error,'no_card_fields');assert.equal(noCardField.value,'');
const invalidPan=new Field('cc-number'),invalid=page([invalidPan]);assert.equal(run(invalid,{action:'fill',url:invalid.location.href,card:{...card,cvc:'bad'}}).error,'invalid_card');assert.equal(invalidPan.value,'');
const maxlengthExpiry=new Field('cc-exp');maxlengthExpiry.maxLength=7;const monthInput=new Field('cc-exp');monthInput.type='month';const formats=page([new Field('cc-number'),maxlengthExpiry,monthInput]);run(formats,{action:'fill',url:formats.location.href,card});assert.equal(maxlengthExpiry.value,'03/2030');assert.equal(monthInput.value,'2030-03');
const partialPan=new Field('cc-number'),missingName=new Field('cc-name'),partial=page([partialPan,missingName]);result=run(partial,{action:'fill',url:partial.location.href,card});assert(result.skipped.includes('name'));assert.equal(missingName.value,'');
console.log('PASS: Safari autofill DOM engine scans without filling, verifies HTTPS/exact URL, fills card/billing formats, skips hidden/shipping/unknown fields, handles frames and never returns credentials');
