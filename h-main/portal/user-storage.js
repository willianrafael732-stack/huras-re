/* Dados locais separados por conta; a sessão Supabase permanece compartilhada. */
(function(root){'use strict';
function createScopedStorage(storage,owner='guest'){let frozen=false;const prefix='hurras-user:'+owner+':';return {owner,getItem(key){const v=storage.getItem(prefix+key);return v===null&&owner==='guest'?storage.getItem(key):v},setItem(key,value){if(frozen)throw Error('A conta mudou. Aguarde o recarregamento.');storage.setItem(prefix+key,String(value))},removeItem(key){if(frozen)return;storage.removeItem(prefix+key);if(owner==='guest')storage.removeItem(key)},database(name){return owner==='guest'?name:name+'-user-'+owner},matches(key,logical){return key===prefix+logical||(owner==='guest'&&key===logical)},freeze(){frozen=true}}}
if(typeof module!=='undefined')module.exports={createScopedStorage};if(typeof window==='undefined')return;
let owner='guest';try{const session=JSON.parse(window.localStorage.getItem('hurras-auth-v1')||'null');if(session?.user?.id)owner=session.user.id}catch{}
root.HurrasStorage=createScopedStorage(window.localStorage,owner);
window.addEventListener('storage',e=>{if(e.key==='hurras-auth-v1'){let next='guest';try{next=JSON.parse(e.newValue||'null')?.user?.id||'guest'}catch{}if(next!==owner){root.HurrasStorage.freeze();location.reload()}}});
})(typeof window!=='undefined'?window:globalThis);
