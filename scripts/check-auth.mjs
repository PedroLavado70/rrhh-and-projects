import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const html=fs.readFileSync('index.html','utf8');
const begin=html.indexOf('function isPreviewUsingProduction(){');
const end=html.indexOf('// Cambiar contraseña en Supabase',begin);
assert.ok(begin>0&&end>begin,'Inicio de sesión protegido no encontrado.');
const source=html.slice(begin,end);

function makeFixture({host='local-staging.test',profile={id:11,name:'Usuario de prueba',role:'admin'},authError=false,loadError=false}={}){
  const ui=new Map();
  const elem=(id)=>{
    if(!ui.has(id))ui.set(id,{
      value:id==='login-email'?'test@example.invalid':id==='login-pwd'?'password-test':'',
      textContent:'',style:{display:'block'},classList:{add(x){this.last=x}}
    });
    return ui.get(id);
  };
  const stats={auth:0,signOut:0,dataLoad:0,goPage:0,roleUI:0};
  const DB={currentUser:{id:null,name:'',role:''},employees:[{id:99}],projects:[],assignments:[]};
  const SB={
    auth:{
      signInWithPassword:async()=>{stats.auth++;return authError?{data:null,error:{message:'bad'}}:{data:{user:{id:'11111111-1111-4111-8111-111111111111'}},error:null};},
      signOut:async()=>{stats.signOut++;}
    },
    from(table){
      assert.equal(table,'usuarios');
      return {
        select(columns){
          assert.ok(!columns.includes('pwd_hash'));
          return {
            eq(field,val){
              assert.equal(field,'auth_user_id');
              return {
                eq(f,v){
                  assert.equal(f,'active');assert.equal(v,true);
                  return {maybeSingle:async()=>({data:profile,error:null})};
                }
              };
            }
          };
        }
      };
    }
  };
  const context={window:{location:{hostname:host}},document:{getElementById:elem,querySelector:()=>({})},
    SUPABASE_URL:'https://amhkybyuwrolursgsicb.supabase.co',SB,DB,
    loadAllData:async()=>{stats.dataLoad++;if(loadError)throw new Error('read failure');},
    updateUserUI:()=>{},applyRoleUI:()=>{stats.roleUI++;},
    goPage:()=>{stats.goPage++;}
  };
  vm.runInNewContext(source,context,{filename:'sigral-login.js'});
  return {...context,ui,stats};
}
const preview=makeFixture({host:'deploy-preview-2--sigralrrhh.netlify.app'});
await preview.window.doLogin();
assert.equal(preview.stats.auth,0,'Preview no debe conectarse a BD producción');
assert.match(preview.document.getElementById('login-error').textContent,/Preproducción no configurada/);

const admin=makeFixture();
await admin.window.doLogin();
assert.equal(admin.stats.auth,1);
assert.equal(admin.stats.dataLoad,1);
assert.equal(admin.stats.goPage,1);
assert.equal(admin.DB.currentUser.role,'admin');
assert.equal(admin.document.getElementById('login-screen').classList.last,'hidden');

const unknown=makeFixture({profile:null});
await unknown.window.doLogin();
assert.equal(unknown.stats.signOut,1);
assert.equal(unknown.stats.dataLoad,0);
assert.equal(unknown.stats.goPage,0);

const wrong=makeFixture({authError:true});
await wrong.window.doLogin();
assert.equal(wrong.stats.dataLoad,0);
assert.equal(wrong.stats.goPage,0);

const missingData=makeFixture({loadError:true});
await missingData.window.doLogin();
assert.equal(missingData.stats.signOut,1);
assert.equal(missingData.stats.goPage,0);
assert.equal(missingData.DB.currentUser.id,null);
assert.equal(missingData.DB.employees.length,0);

console.log('OK: login admin, credenciales erróneas, usuario no autorizado, fallo de carga y preview de producción bloqueada.');
