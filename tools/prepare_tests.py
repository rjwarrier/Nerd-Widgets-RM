from pathlib import Path
root=Path(__file__).resolve().parents[1]
test=root/'.tools/TestSkins/ModelTests'
test.mkdir(parents=True,exist_ok=True)
text=f'''[Rainmeter]
Update=-1
[Variables]
Source={root}\\NerdWidgets\\@Resources\\Scripts\\
Result={root}\\.tools\\test-result.txt
[Test]
Measure=Script
ScriptFile={root}\\tools\\ModelTests.lua
[Status]
Meter=String
Text=Model checks - see test-result.txt
Hidden=1
'''
(test/'Tests.ini').write_text(text,encoding='utf-16')
print(test/'Tests.ini')
