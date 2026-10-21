(function(root){"use strict";
const fold=s=>(s||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLocaleLowerCase("pt-BR");
const headings=/^(?:Atributos|Habilidades|Magias\s*\/\s*Técnicas|Magias\/Técnicas|Elementos Mágicos|Resistências(?:\s+Magica|\s+Mágicas)?|Descrição|Habitat|Drops?|Armas?|Arma Principal|Talentos|Perícias|Conhecimentos|Passivas?|Fraquezas|História|Equipamento|Árvores de Magia|Técnicas|Poderes)\s*:?\s*$/i;
function parse(text){
 const lines=text.replace(/\f/g,"\n").split(/\r?\n/),starts=[];let currentLevel=1;
 for(let i=0;i<lines.length;i++){
  const lev=lines[i].trim().match(/^Nível\s*:?\s*(\d+)\s*$/i);
  if(lev)currentLevel=Number(lev[1]);
  if(!/^\s*Vitalidade\s*:/i.test(lines[i]))continue;
  let j=i-1;while(j>=0&&!lines[j].trim())j--;
  while(j>=0&&/^(Raça|Classe|Tipo|Categoria)\s*:/i.test(lines[j].trim())){j--;while(j>=0&&!lines[j].trim())j--}
  const name=(lines[j]||"").trim();
  if(!name||headings.test(name)||/^[-•\d]|^Nível\b|^Vitalidade\b/i.test(name))continue;
  starts.push({start:j,name,level:currentLevel});
 }
 return starts.map((entry,i)=>{
  const raw=lines.slice(entry.start,i+1<starts.length?starts[i+1].start:lines.length).join("\n").trim();
  const sections=[];let current={heading:"Ficha e atributos",text:[]};sections.push(current);
  for(const line of raw.split("\n")){
   const cleaned=line.trim();
   if(headings.test(cleaned)){current={heading:cleaned.replace(/:$/,""),text:[]};sections.push(current)}
   else current.text.push(line);
  }
  const part=(name)=>{const found=sections.find(x=>fold(x.heading).startsWith(fold(name)));return found?found.text.join("\n").trim():""};
  const life=raw.match(/^\s*Vitalidade\s*:\s*([^\n]+)/mi),mana=raw.match(/^\s*Mana\s*:\s*([^\n]+)/mi);
  return {...entry,raw,sections,description:part("Descrição"),habitat:part("Habitat"),life:life&&life[1].trim(),mana:mana&&mana[1].trim()};
 });
}
const api={parse,fold};root.HurrasBestiary=api;if(typeof module!=="undefined")module.exports=api;
})(typeof window!=="undefined"?window:globalThis);
