"""Host-only regression checks. Never loads a kext or accesses microphone hardware."""
from pathlib import Path
import subprocess
import tempfile
root=Path(tempfile.mkdtemp(prefix='sst-host-test-'))
candidate=Path(__file__).resolve().parent.parent/'Source/IntelSSTDMIC'
s=(candidate/'IntelDspAudioEngine.cpp').read_text()
start=s.index('bool IntelDspAudioEngine::isInternalMicEngine(')
end=s.index('\nbool IntelDspAudioEngine::isAlive()',start)
function=s[start:end]
pre=r'''
#include <string>
#include <map>
#include <cassert>
#include <cstdio>
struct OSObject {virtual ~OSObject() = default;};
struct OSString: OSObject {std::string value; OSString(const char *s):value(s){} bool isEqualTo(const char *s){return value==s;}};
struct OSNumber: OSObject {unsigned value; OSNumber(unsigned n):value(n){} unsigned unsigned32BitValue(){return value;}};
struct OSDictionary: OSObject {std::map<std::string,OSObject*> props; OSObject *getObject(const char *k){return props[k];}};
struct IOService {std::map<std::string,OSObject*> props; OSObject *getProperty(const char *k){return props[k];}};
#define OSDynamicCast(T, p) dynamic_cast<T *>(p)
struct IntelDspAudioEngine {bool isInternalMicEngine(IOService *self) const;};
'''
post=r'''
int main(){
 IntelDspAudioEngine engine;
 auto check=[&](const char *name,int count,bool expect){
   IOService s;OSString label(name);OSNumber n(count<0?0:count);OSDictionary d;
   s.props["IOAudioEngineDescription"]=&label;
   if(count>=0){d.props["num-internal-mics"]=&n;s.props["IOAudioEngineDeviceDescription"]=&d;}
   assert(engine.isInternalMicEngine(&s)==expect);
 };
 check("DevShortNameIMic",-1,true);
 check("内建麦克风",1,true);
 check("Internal Microphone",1,true);
 check("任意翻译",2,true);
 check("内建线路输入",0,false);
 check("Headset Microphone",0,false);
 check("内建麦克风",-1,false);
 check("内建麦克风",0,false);
 assert(!engine.isInternalMicEngine(nullptr));
 IOService s;OSDictionary d;OSString bad("1");d.props["num-internal-mics"]=&bad;
 s.props["IOAudioEngineDeviceDescription"]=&d;assert(!engine.isInternalMicEngine(&s));
 puts("PASS: 10 cases against actual candidate isInternalMicEngine function");
}
'''
out=root/'host-tests';out.mkdir(exist_ok=True)
cpp=out/'identity-test.cpp'
with cpp.open('x') as f:f.write(pre+function+post)
subprocess.run(['clang++','-std=c++17',str(cpp),'-o',str(out/'identity-test')],check=True)
subprocess.run([str(out/'identity-test')],check=True)
glue=(candidate/'LiluGlue.cpp').read_text()
assert glue.index('if (id != appleHDAInfo.loadIndex)') < glue.index('HookManager::install(')
assert 'status.ignoredKextCb++;\n        return;' in glue
hook=(candidate/'HookManager.cpp').read_text()
assert 'routeMultiple(kextId, &request, 1, address, size)' not in hook
assert 'routeMultiple(kextId, &request, 1);' in hook
assert 'getParentEntry(gIOServicePlane)' in s
print('PASS: callback filter, no unsafe callback-range retry, PCI ancestry guard retained')
