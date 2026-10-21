/* Bestiário oficial: o texto original é carregado sem alterar as descrições. */
(()=>{"use strict";
const $=id=>document.getElementById(id);
const root=$("archiveGrid"),search=$("archiveSearch"),level=$("archiveLevel"),count=$("archiveCount"),more=$("archiveMore"),print=$("archivePrint");
if(!root||!search||!level||!count||!more)return;
const fold=s=>(s||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLocaleLowerCase("pt-BR");
const elem=(tag,content,cls)=>{const node=document.createElement(tag);if(content!==null)node.textContent=content;if(cls)node.className=cls;return node};
const headings=/^(?:Atributos|Habilidades|Magias\s*\/\s*Técnicas|Magias\/Técnicas|Elementos Mágicos|Resistências(?:\s+Magica|\s+Mágicas)?|Descrição|Habitat|Drops?|Armas?|Arma Principal|Talentos|Perícias|Conhecimentos|Passivas?|Fraquezas|História|Equipamento|Árvores de Magia|Técnicas|Poderes)\s*:?\s*$/i;
let all=[],limit=20;
const parse=window.HurrasBestiary.parse;
function render(){
 const query=fold(search.value.trim()),lvl=level.value;
 const filtered=all.filter(x=>(!query||fold(x.name+" "+x.raw).includes(query))&&(!lvl||String(x.level)===lvl));
 root.replaceChildren();
 for(const c of filtered.slice(0,limit)){
  const card=elem("article",null,"archive-card"),header=elem("div",null,"archive-heading");
  const title=elem("h3",c.name),badge=elem("span","Nível "+c.level,"archive-tag");header.append(title,badge);card.append(header);
  const stats=elem("p",null,"archive-stats");stats.textContent="❤ Vitalidade: "+(c.life||"não informada")+"  •  ✦ Mana: "+(c.mana||"não informada");card.append(stats);
  if(c.description){const text=c.description.replace(/\s+/g,' ').trim();card.append(elem('p',text.length>190?text.slice(0,187)+'…':text,'archive-description'));}
  const techniques=c.sections.find(x=>fold(x.heading).includes('magias'));
  if(techniques){const quick=elem('section',null,'archive-quick');quick.append(elem('h4','Ataques e técnicas'));const lines=techniques.text.join('\n').trim().split(/\n(?=\s*[-•])/).map(x=>x.trim()).filter(Boolean);const list=elem('ul');for(const line of lines.slice(0,2))list.append(elem('li',line.replace(/^[-•]\s*/,'')));quick.append(list);if(lines.length>2)quick.append(elem('small','Mais '+(lines.length-2)+' técnica(s) na ficha completa.'));card.append(quick);}
  const details=elem("details",null,"archive-details"),summary=elem("summary","Ver atributos, habilidades e ficha completa");
  const body=elem("div",null,"archive-body");
  for(const section of c.sections){
   const clean=section.text.join("\n").trim();if(!clean)continue;
   const h=elem('h4',section.heading),content=elem('div',null,'archive-readable');
   const parts=clean.split(/\n(?=\s*[-•])/).map(x=>x.trim()).filter(Boolean);
   if(parts.some(x=>/^[-•]/.test(x))){const list=elem('ul');for(const part of parts)list.append(elem('li',part.replace(/^[-•]\s*/,'')));content.append(list);}else content.append(elem('p',clean.replace(/\s+/g,' ')));
   body.append(h,content);
  }
  const original=elem("details"),originalSum=elem("summary","Ver texto integral sem alterações"),pre=elem("pre",c.raw,"archive-pre");
  original.append(originalSum,pre);body.append(original);details.append(summary,body);card.append(details);root.append(card);
 }
 count.textContent=filtered.length+" fichas encontradas no arquivo original · mostrando "+Math.min(filtered.length,limit);
 more.hidden=filtered.length<=limit;
 if(!filtered.length)root.append(elem("p","Nenhuma ficha encontrada. Tente outro nome ou nível.","archive-empty"));
}
function addSelect(){
 const nums=[...new Set(all.map(c=>c.level))].sort((a,b)=>a-b);for(const n of nums){const op=elem("option","Nível "+n);op.value=String(n);level.append(op)}
}
search.addEventListener("input",()=>{limit=20;render()});level.addEventListener("change",()=>{limit=20;render()});
more.addEventListener("click",()=>{limit+=20;render()});
print.addEventListener("click",()=>{limit=Number.MAX_SAFE_INTEGER;render();root.querySelectorAll("details").forEach(d=>d.open=true);window.print()});
fetch("dados/bestiario-original.txt").then(r=>{if(!r.ok)throw Error("HTTP "+r.status);return r.text()}).then(text=>{all=parse(text);all.sort((a,b)=>a.name.localeCompare(b.name,'pt-BR')||a.level-b.level);addSelect();render();}).catch(err=>{count.textContent="Falha ao carregar arquivo: "+err.message;root.replaceChildren(elem("p","Não foi possível abrir as fichas. Recarregue a página.","archive-empty"))});
})();