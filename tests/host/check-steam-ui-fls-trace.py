#!/usr/bin/env python3
"""Apply the real Wine observer patch in a temp tree; check gating/privacy/bounds.
Mock environment/TEB and debug sink only. This is not device/FLS correctness.
"""
from pathlib import Path
import os,re,subprocess,tempfile
root=Path(__file__).resolve().parents[2]
original=(root/'wine/dlls/ntdll/thread.c').read_text()
with tempfile.TemporaryDirectory() as td:
    td=Path(td); f=td/'dlls/ntdll/thread.c';f.parent.mkdir(parents=True);f.write_text(original)
    subprocess.run(['patch','-s','-p1','-d',str(td),'-i',str(root/'build/wine-pe/steam-ui-fls-trace.patch')],check=True)
    changed=f.read_text();a=changed.index('/* Steam UI lab: bounded metadata only;');b=changed.index('static void lock_fls_data(void)',a)
    helper=changed[a:b]
    uninstrumented=changed[:a]+changed[b:]
    uninstrumented='\n'.join(l for l in uninstrumented.splitlines() if 'steam_ui_fls_event(' not in l)
    assert re.sub(r'\s+',' ',uninstrumented).strip()==re.sub(r'\s+',' ',original).strip(), 'observer must not change existing callback behavior'
    fixture=r'''
#include <stdio.h>
#include <stdint.h>
#include <stdarg.h>
#include <string.h>
#include <wchar.h>
#include <stdlib.h>
typedef long LONG;
typedef unsigned long ULONG;
typedef uintptr_t ULONG_PTR;
typedef wchar_t WCHAR;
typedef struct { unsigned short Length,MaximumLength; WCHAR *Buffer; } UNICODE_STRING;
struct params { WCHAR *Environment; };
struct peb { struct params *ProcessParameters; };
typedef struct { struct peb *Peb; struct {void *UniqueProcess,*UniqueThread;} ClientId; } TEB;
static struct params params={L"PRIVATE_PASSWORD_TOKEN"};
static struct peb peb={&params};
static TEB teb={&peb,{(void*)17,(void*)19}};
static TEB *current=&teb;
static int session,trace;
static TEB *NtCurrentTeb(void){return current;}
static void RtlInitUnicodeString(UNICODE_STRING *s,const WCHAR *v){s->Buffer=(WCHAR*)v;s->Length=wcslen(v)*sizeof(WCHAR);}
static int RtlQueryEnvironmentVariable_U(WCHAR *env,UNICODE_STRING *name,UNICODE_STRING *value){
    int on=!wcscmp(name->Buffer,L"MADEIRA_STEAM_UI_SESSION")?session:trace;
    value->Length=sizeof(WCHAR);value->Buffer[0]=on?'1':'0';return 0;
}
static LONG InterlockedExchange(LONG *p,LONG v){return __atomic_exchange_n(p,v,__ATOMIC_SEQ_CST);}
static LONG InterlockedIncrement(LONG *p){return __atomic_add_fetch(p,1,__ATOMIC_SEQ_CST);}
static int wine_dbg_printf(const char *format,...){va_list a;va_start(a,format);int n=vprintf(format,a);va_end(a);return n;}
'''
    main=r'''
int main(int argc,char **argv){
    session=argc>1 && strchr(argv[1],'s');trace=argc>1 && strchr(argv[1],'t');
    if(argc>1 && strchr(argv[1],'n'))current=NULL;
    char private_data[]="SECRET_ACCOUNT_PAYLOAD";
    for(int i=0;i<4100;i++)steam_ui_fls_event("set",7,private_data,(void*)0x1234,(void*)0x5678);
    return 0;
}
'''
    c=td/'check.c';c.write_text(fixture+helper+main)
    subprocess.run(['cc','-fsanitize=address,undefined',str(c),'-o',str(td/'check')],check=True)
    for arg in ['', 's','t','stn']:
        p=subprocess.run([str(td/'check'),arg],capture_output=True,text=True,check=True);assert not p.stdout
    p=subprocess.run([str(td/'check'),'st'],capture_output=True,text=True,check=True)
    lines=p.stdout.splitlines();assert len(lines)==4096 and 'seq=4096' in lines[-1]
    assert all('[steam-ui-fls]' in l and 'event=set' in l and 'index=7' in l for l in lines)
    assert 'PRIVATE' not in p.stdout and 'SECRET' not in p.stdout and 'PAYLOAD' not in p.stdout
print('PASS: production patch preserves callback behavior; both flags required; null TEB safe; capped at 4096 metadata records; no pointed-to payload emitted (ASan/UBSan)')
