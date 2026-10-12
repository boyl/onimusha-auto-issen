import pathlib,sys,json
ROOT=pathlib.Path(__file__).resolve().parents[1]
if len(sys.argv)>1:sys.path.insert(0,sys.argv[1])
from lupa.lua54 import LuaRuntime
results={'lua_version':'5.4','syntax':[],'tests':{}}
lua=LuaRuntime(unpack_returned_tuples=True)
compile_lua=lua.eval('function(s,n) local f,e=load(s,n,"t",{}); return f~=nil,e end')
for path in sorted((ROOT/'reframework').rglob('*.lua')):
    ok,error=compile_lua(path.read_text(encoding='utf-8'),'@'+str(path))
    assert ok,(path,error)
    results['syntax'].append(str(path.relative_to(ROOT)))
lua.globals().ROOT=ROOT.as_posix()
for path in sorted((ROOT/'tests').glob('*_test.lua')):
    results['tests'][path.name]=lua.execute(path.read_text(encoding='utf-8'))
print(json.dumps(results,ensure_ascii=False,indent=2))
(ROOT/'docs/acceptance/automated-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
