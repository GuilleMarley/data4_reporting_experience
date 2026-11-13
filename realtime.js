window.Data4Realtime=(()=>{
  const cfg=window.DATA4_CONFIG||{};
  const session=cfg.DEFAULT_SESSION||'D4DEMO';
  const enabled=!!(cfg.SUPABASE_URL&&cfg.SUPABASE_PUBLISHABLE_KEY&&window.supabase);
  const db=enabled?window.supabase.createClient(cfg.SUPABASE_URL,cfg.SUPABASE_PUBLISHABLE_KEY):null;
  let clientId=localStorage.getItem('data4_client_id');
  if(!clientId){clientId=(crypto.randomUUID?crypto.randomUUID():Date.now()+'-'+Math.random());localStorage.setItem('data4_client_id',clientId);}
  async function getPhase(){if(!db)return localStorage.getItem('data4_phase')||'lobby';const {data,error}=await db.from('demo_sessions').select('phase').eq('code',session).single();if(error)throw error;return data.phase;}
  async function setPhase(phase,pin){if(!db){localStorage.setItem('data4_phase',phase);return true;}const {data,error}=await db.rpc('set_demo_phase',{p_code:session,p_pin:pin,p_phase:phase});if(error)throw error;return data===true;}
  function subscribePhase(cb){if(!db)return null;return db.channel('data4-phase').on('postgres_changes',{event:'UPDATE',schema:'public',table:'demo_sessions',filter:'code=eq.'+session},p=>cb(p.new.phase)).subscribe();}
  async function register(role){if(!db)return;const {error}=await db.from('participants').upsert({session_code:session,client_id:clientId,role},{onConflict:'session_code,client_id'});if(error)throw error;}
  async function respond(role,phase,answer){if(!db)return;const {error}=await db.from('responses').insert({session_code:session,client_id:clientId,role,phase,answer:String(answer)});if(error)throw error;}
  async function stats(){if(!db)return null;const [{data:parts},{data:resp}]=await Promise.all([db.from('participants').select('role').eq('session_code',session),db.from('responses').select('role,phase,answer').eq('session_code',session)]);return {participants:parts||[],responses:resp||[]};}
  return {enabled,db,session,clientId,getPhase,setPhase,subscribePhase,register,respond,stats};
})();