/* Misturas autorais de campanha. A pontuação dos dados usa HurrasD10. */
(function(root){'use strict';
function createEngine(data){
 const elements=data.elements,byId=new Map(elements.map(e=>[e.id,e]));
 const key=ids=>[...ids].sort().join('|');
 const recipes=new Map(data.recipes.map(r=>[key(r.elements),r]));
 function combine(ids,dice,mana){
  const selected=[...new Set(ids)].map(id=>byId.get(id));
  if(selected.some(e=>!e))throw Error('Elemento inválido.');
  selected.sort((a,b)=>elements.indexOf(a)-elements.indexOf(b));
  if(selected.length<2)throw Error('Selecione pelo menos dois elementos.');
  if(!Number.isInteger(dice)||dice<1||dice>200)throw Error('Use de 1 a 200 dados d10.');
  if(!Number.isInteger(mana)||mana<0||mana>9999)throw Error('Use um custo inteiro de 0 a 9999 Mana.');
  const recipe=recipes.get(key(selected.map(e=>e.id)));
  return {ids:selected.map(e=>e.id),name:recipe?.name||(selected.length===elements.length?'Convergência Primordial':'Convergência de '+selected.map(e=>e.name).join(' + ')),effect:recipe?.effect||'Uma manifestação reúne '+selected.map(e=>e.name).join(', ')+'. Escolha um único efeito principal com o mestre. Combinar mais elementos não concede ações, dano ou imunidades adicionais.',dice,mana};
 }
 return {elements,recipes:data.recipes,combine};
}
if(typeof module!=='undefined')module.exports={createEngine};
if(typeof document==='undefined')return;
const $=id=>document.getElementById(id),status=$('status'),selected=new Set(),storageKey='hurras.elemental-mixtures.v1';
let engine,current=null,saved=[];
function elem(tag,text,cls){const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n}
function loadSaved(){try{const raw=JSON.parse(localStorage.getItem(storageKey)||'[]');if(!Array.isArray(raw))return [];return raw.slice(0,50).flatMap(x=>{try{return [engine.combine(x.ids,x.dice,x.mana)]}catch{return []}})}catch{status.textContent='O armazenamento local está indisponível. Você ainda pode combinar e imprimir.';return []}}
function persist(){try{localStorage.setItem(storageKey,JSON.stringify(saved));return true}catch{status.textContent='Não foi possível salvar neste navegador. Use Imprimir / PDF para guardar a mistura.';return false}}
function update(){
 current=null;$('rollOutput').textContent='';$('selectionCount').textContent=selected.size+' de '+engine.elements.length+' elementos selecionados';
 for(const input of $('elements').querySelectorAll('input'))input.checked=selected.has(input.value);
 try{if($('dice').value===''||$('mana').value==='')throw Error('Preencha a quantidade de dados e o custo de Mana.');current=engine.combine([...selected],Number($('dice').value),Number($('mana').value));$('resultName').textContent=current.name;$('resultElements').textContent=current.ids.map(id=>engine.elements.find(e=>e.id===id).name).join(' + ');$('resultEffect').textContent=current.effect;$('power').textContent=current.dice+'d10';$('cost').textContent=current.mana+' Mana'}catch(e){$('resultName').textContent=selected.size<2?'Escolha dois elementos':'Confira os valores';$('resultElements').textContent='';$('resultEffect').textContent=e.message}
 $('resultStats').hidden=!current;for(const id of ['roll','save','print'])$(id).disabled=!current;
}
function choose(ids){selected.clear();ids.forEach(id=>selected.add(id));update()}
function renderRecipes(){const fold=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();const q=fold($('recipeSearch').value.trim());const list=engine.recipes.filter(r=>fold(r.name+' '+r.effect+' '+r.elements.map(id=>engine.elements.find(e=>e.id===id).name).join(' ')).includes(q));$('recipes').replaceChildren();for(const r of list){const a=elem('article',undefined,'recipe');a.append(elem('small',r.elements.map(id=>engine.elements.find(e=>e.id===id).name).join(' + ')),elem('h3',r.name),elem('p',r.effect));const button=elem('button','Usar combinação');button.type='button';button.onclick=()=>{choose(r.elements);$('resultName').scrollIntoView({behavior:'smooth',block:'center'})};a.append(button);$('recipes').append(a)}$('recipeCount').textContent=list.length+' de '+engine.recipes.length+' combinações em dupla'}
function renderSaved(){ $('saved').replaceChildren();$('savedEmpty').hidden=!!saved.length;for(const [i,r]of saved.entries()){const a=elem('article',undefined,'recipe');a.append(elem('h3',r.name),elem('p',r.dice+'d10 · '+r.mana+' Mana'));const actions=elem('div',undefined,'actions'),open=elem('button','Abrir'),remove=elem('button','Remover');open.onclick=()=>{$('dice').value=r.dice;$('mana').value=r.mana;choose(r.ids);$('resultName').scrollIntoView({behavior:'smooth',block:'center'})};remove.setAttribute('aria-label','Remover '+r.name);remove.onclick=()=>{const next=saved.filter((_,index)=>index!==i),before=saved;saved=next;if(!persist())saved=before;renderSaved()};actions.append(open,remove);a.append(actions);$('saved').append(a)}}
async function init(){try{const response=await fetch('dados/misturas-elementais.json');if(!response.ok)throw Error('HTTP '+response.status);engine=createEngine(await response.json());for(const e of engine.elements){const label=elem('label',undefined,'element');label.style.setProperty('--color',e.color);const input=elem('input');input.type='checkbox';input.value=e.id;input.addEventListener('change',()=>{if(input.checked)selected.add(e.id);else selected.delete(e.id);update()});label.append(elem('span',e.icon),elem('strong',e.name),input);$('elements').append(label)}
 $('selectAll').disabled=$('clear').disabled=false;$('selectAll').onclick=()=>choose(engine.elements.map(e=>e.id));$('clear').onclick=()=>choose([]);$('dice').addEventListener('input',update);$('mana').addEventListener('input',update);$('recipeSearch').addEventListener('input',renderRecipes);$('print').onclick=()=>root.print();$('roll').onclick=()=>{if(!current)return;try{const d=root.HurrasD10,r=d.score(Array.from({length:current.dice},()=>d.face(10)));$('rollOutput').textContent='Dados: '+r.values.join(', ')+'\n'+d.describe(r)}catch{$('rollOutput').textContent='Não foi possível abrir o rolador d10. Recarregue a página.'}};
 $('save').onclick=()=>{if(!current)return;const duplicate=saved.some(x=>JSON.stringify(x.ids)===JSON.stringify(current.ids)&&x.dice===current.dice&&x.mana===current.mana);if(duplicate){status.textContent='Esta mistura já está salva.';return}if(saved.length>=50){status.textContent='Você já tem 50 misturas salvas. Remova uma para salvar outra.';return}saved.push(current);if(persist()){status.textContent='Mistura salva neste navegador.';renderSaved()}else saved.pop()};status.textContent='';saved=loadSaved();renderSaved();renderRecipes();update();
 }catch{status.textContent='Não foi possível carregar os elementos. Recarregue a página para tentar novamente.'}}
init();
})(typeof window!=='undefined'?window:globalThis);
