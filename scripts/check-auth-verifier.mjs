import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const html=fs.readFileSync('verificar-auth.html','utf8');
const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(m=>m[1]).filter(s=>s.trim());
assert.equal(scripts.length,1);
new vm.Script(scripts[0]);
assert.match(html,/auth\.signInWithPassword/);
assert.match(html,/persistSession:false/);
assert.match(html,/auth\.signOut/);
assert.doesNotMatch(html,/pwd_hash/);
let windowLoad;
const submitHandlers={};
const cells=new Map();
for(const id of ['login','email','password','status','send'])cells.set(id,{
  value:id==='email'?'test@example.invalid':id==='password'?'test password':'',
  textContent:'',disabled:false,addEventListener(name,fn){submitHandlers[name]=fn;}
});
let signIns=0,signOuts=0;
const client={
  auth:{
    signInWithPassword:async()=>{signIns++;return {data:{user:{id:'fake-user'}},error:null};},
    signOut:async()=>{signOuts++;return {error:null};}
  }
};
const window={
 addEventListener:(name,fn)=>{if(name==='load')windowLoad=fn;},
 supabase:{createClient:(url,key,options)=>{assert.equal(options.auth.persistSession,false);return client;}}
};
const document={getElementById:(id)=>cells.get(id)};
vm.runInNewContext(scripts[0],{window,document,console});
assert.equal(typeof windowLoad,'function');
windowLoad();
await submitHandlers.submit({preventDefault(){}});
assert.equal(signIns,1);assert.equal(signOuts,1);
assert.match(cells.get('status').textContent,/CONTRASEÑA CORRECTA/);
assert.equal(cells.get('password').value,'');
assert.equal(cells.get('send').disabled,false);
console.log('OK: verificación independiente de Supabase Auth, cierre de sesión y limpieza de contraseña.');
