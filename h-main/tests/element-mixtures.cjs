const assert=require('node:assert/strict');
const {createEngine}=require('../funcoes/js/mistura-elementos.js');
const data=require('../funcoes/dados/misturas-elementais.json');
const engine=createEngine(data),ids=data.elements.map(e=>e.id);
assert.equal(new Set(ids).size,9);
assert.equal(data.recipes.length,ids.length*(ids.length-1)/2);
const seen=new Set();
for(let i=0;i<ids.length;i++)for(let j=i+1;j<ids.length;j++){
 const a=engine.combine([ids[i],ids[j]],3,5),b=engine.combine([ids[j],ids[i]],3,5);
 assert.deepEqual(a,b);assert(!a.name.startsWith('Convergência'));assert.equal(a.dice,3);seen.add(a.name);
}
assert.equal(seen.size,36);
const all=engine.combine(ids,3,5);assert.equal(all.name,'Convergência Primordial');assert.equal(all.dice,3);assert.equal(all.mana,5);
assert.deepEqual(engine.combine([...ids,ids[0]],3,5),all);
assert.throws(()=>engine.combine(['fogo'],3,5));assert.throws(()=>engine.combine(['fogo','inventado'],3,5));
for(const invalid of [0,201,NaN,1.5])assert.throws(()=>engine.combine(['fogo','agua'],invalid,5));
for(const invalid of [-1,10000,NaN,1.5])assert.throws(()=>engine.combine(['fogo','agua'],3,invalid));
assert.equal(engine.combine(['fogo','agua'],200,0).mana,0);
console.log('36 receitas únicas, ordem reversa, convergência total e limites: OK.');
