"""Original articulated-magic geometry plus OBJ/MTL import sources; no downloaded models."""
from pathlib import Path
import math
import json
import xml.etree.ElementTree as ET
import build_assets as base

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'magic'
MESHES = ROOT / 'meshes'
OUT.mkdir(exist_ok=True)
MESHES.mkdir(exist_ok=True)
manifest = {}
ivory, dark, red = (224, 215, 193), (24, 23, 34), (245, 48, 73)
water, wind, gold = (98, 200, 245), (97, 233, 154), (225, 191, 107)

def add(a,b): return tuple(x+y for x,y in zip(a,b))
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def mul(a,k): return tuple(x*k for x in a)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(a): return mul(a,1/max(1e-9,math.sqrt(dot(a,a))))
def matvec(m,v): return tuple(dot(row,v) for row in m)
def columns(x,y,z): return tuple((x[i],y[i],z[i]) for i in range(3))

class Asset:
    def __init__(self,name):
        self.name=name;self.doc=base.document();self.model=base.item(self.doc,'Model',name);self.parts=[]
        root=base.part(self.model,'Root',(0,0,0),(.1,.1,.1),dark,anchored=True,collide=False,transparency=1)
        base.prop(self.model,'Ref','PrimaryPart',root.attrib['referent'])
    def p(self,name,pos,size,color,shape=1,matrix=base.IDENTITY,material=272,alpha=0):
        cls='WedgePart' if shape==3 else 'Part'
        node=base.part(self.model,name,pos,size,color,material,matrix,None if shape==3 else shape,cls,True,False,alpha)
        self.parts.append((name,pos,size,color,shape,matrix))
        return node
    def rod(self,name,a,b,r,color,knuckle=False):
        right=norm(sub(b,a));aux=(0,1,0) if abs(right[1])<.9 else (0,0,1)
        up=norm(sub(aux,mul(right,dot(aux,right))));back=cross(right,up)
        self.p(name,mul(add(a,b),.5),(math.sqrt(dot(sub(b,a),sub(b,a))),r*2,r*2),color,2,columns(right,up,back))
        if knuckle:self.p(name+'Joint',b,(r*2.7,)*3,color,0)
    def curve(self,name,points,r,color):
        for i,(a,b) in enumerate(zip(points,points[1:])):
            self.rod(name+str(i),a,b,r*(1-i/max(1,len(points))*.7),color,i<len(points)-2)
    def triangle(self,name,a,b,c,color,thickness=.045):
        ab,ac,bc=sub(b,a),sub(c,a),sub(c,b)
        if dot(ab,ab)>max(dot(ac,ac),dot(bc,bc)):a,c=c,a
        elif dot(ac,ac)>max(dot(ab,ab),dot(bc,bc)):a,b=b,a
        ab,ac,bc=sub(b,a),sub(c,a),sub(c,b)
        right=norm(cross(ac,ab));back=norm(bc);up=norm(cross(bc,right));height=abs(dot(ab,up))
        if height<.001:return
        self.p(name+'A',mul(add(a,b),.5),(thickness,height,max(.01,abs(dot(ab,back)))),color,3,columns(right,up,back))
        self.p(name+'B',mul(add(a,c),.5),(thickness,height,max(.01,abs(dot(ac,back)))),color,3,columns(mul(right,-1),up,mul(back,-1)))
    def finish(self):
        ET.indent(self.doc)
        ET.ElementTree(self.doc).write(OUT/(self.name+'.rbxmx'),encoding='utf-8',xml_declaration=True)
        export_obj(self)

def primitive(shape):
    if shape==3:
        return [(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)],[(0,2,3,1),(2,4,5,3),(0,1,5,4),(0,4,2),(1,3,5)]
    if shape==2:
        count=12;v=[]
        for x in (-.5,.5):
            v.extend((x,math.cos(i*math.tau/count)*.5,math.sin(i*math.tau/count)*.5) for i in range(count))
        f=[tuple(range(count-1,-1,-1)),tuple(range(count,2*count))]
        f.extend((i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count))
        return v,f
    if shape==0:
        n,m=12,8;v=[];f=[]
        for j in range(m+1):
            a=j*math.pi/m
            for i in range(n):v.append((.5*math.sin(a)*math.cos(i*math.tau/n),.5*math.cos(a),.5*math.sin(a)*math.sin(i*math.tau/n)))
        for j in range(m):
            for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
        return v,f
    return [(-.5,-.5,-.5),(.5,-.5,-.5),(.5,.5,-.5),(-.5,.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(.5,.5,.5),(-.5,.5,.5)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)]

def export_obj(asset):
    lines=[f'mtllib {asset.name}.mtl',f'o {asset.name}'];offset=0;materials={};all_vertices=[]
    for name,pos,size,color,shape,matrix in asset.parts:
        mat='m'+str(len(materials)) if color not in materials else materials[color]
        materials[color]=mat;lines.append('usemtl '+mat)
        vertices,faces=primitive(shape)
        vertices=[add(pos,matvec(matrix,tuple(x*s for x,s in zip(v,size)))) for v in vertices]
        all_vertices.extend(vertices)
        lines.extend('v '+' '.join(f'{x:.6f}' for x in v) for v in vertices)
        for face in faces:
            for i in range(1,len(face)-1):lines.append('f '+' '.join(str(offset+k+1) for k in (face[0],face[i],face[i+1])))
        offset+=len(vertices)
    (MESHES/(asset.name+'.obj')).write_text('\n'.join(lines)+'\n')
    mtl=[]
    for color,name in materials.items():mtl.extend([f'newmtl {name}','Kd '+' '.join(f'{c/255:.5f}' for c in color),'Ka 0.1 0.1 0.1','Ks 0.2 0.2 0.2','Ns 30'])
    (MESHES/(asset.name+'.mtl')).write_text('\n'.join(mtl)+'\n')
    low=[min(v[i] for v in all_vertices) for i in range(3)];high=[max(v[i] for v in all_vertices) for i in range(3)]
    manifest[asset.name]={'parts':len(asset.parts),'vertices':len(all_vertices),'center':[(a+b)/2 for a,b in zip(low,high)],'size':[b-a for a,b in zip(low,high)]}

def weapons():
    a=Asset('AntiSword')
    a.rod('Grip',(0,-.7,0),(0,.7,0),.16,dark)
    for y in (-.5,-.25,0,.25,.5):a.p('GripBand',(0,y,0),(.37,.07,.37),(86,67,67),2,base.rotation(z=math.pi/2))
    a.p('Pommel',(0,-.85,0),(.5,.45,.5),(75,69,76),0)
    a.p('Guard',(0,.8,0),(2.1,.3,.48),(77,72,81))
    a.p('Blade',(0,3.45,0),(1.6,5,.32),dark)
    for sign in (-1,1):
        a.p('BrokenEdge',(sign*.85,3.3,0),(.23,4.7,.39),(76,72,83),3,base.rotation(y=math.pi if sign<0 else 0))
        a.p('BladeShoulder',(sign*.7,1.3,0),(.6,1,.35),dark,3,base.rotation(z=sign*-.35))
    a.p('Tip',(0,6,0),(1.6,1,.32),(65,60,72),3,base.rotation(z=math.pi))
    a.curve('CrimsonCrack',[(-.25,1,-.19),(.3,2,-.19),(-.15,3.3,-.19),(.25,4.2,-.19),(0,5.7,-.19)],.045,red)
    a.finish()
    for name,color in [('WaterSpear',water),('BoneSpear',ivory),('WindWeapon',wind)]:
        a=Asset(name);a.rod('Shaft',(0,-1.5,0),(0,4,0),.1,color)
        a.p('Blade',(0,4.6,0),(.8,1.6,.25),color,3,base.rotation(z=math.pi),288 if name!='BoneSpear' else 272)
        for sign in (-1,1):
            a.curve('Guard',[(0,.8,0),(sign*.7,1.2,0),(sign*.4,1.9,0)],.09,color)
            a.p('Fin',(sign*.36,3.9,0),(.5,1.2,.12),color,3,base.rotation(z=sign*.4))
        for y in (-.4,0,.4):a.p('GripWrap',(0,y,0),(.25,.1,.25),gold,2,base.rotation(z=math.pi/2))
        a.finish()

def wings():
    for element in ('Bone','Water','Wind','Anti'):
        for side,sign in [('Left',-1),('Right',1)]:
            a=Asset(element+'Wing'+side)
            color={'Bone':ivory,'Water':water,'Wind':wind,'Anti':dark}[element]
            membrane=dark if element in ('Bone','Anti') else tuple(int(v*.7) for v in color)
            def p(x,y,z):return (x*sign,y,z)
            shoulder=p(.1,0,0);elbow=p(2.5,2,.3);tip=p(6.5,3.7,.6)
            a.curve('WingArm',[shoulder,elbow,tip],.16,color)
            ends=[p(6.8,1.6,.8),p(5.6,-.4,1.3),p(3.9,-2.1,1),p(1.7,-2.9,.6)]
            previous=tip
            for i,end in enumerate(ends):
                joint=p(3.5+i*.35,1.3-i*.3,.6)
                a.curve('Finger'+str(i),[elbow,joint,end],.105,color)
                a.triangle('Membrane'+str(i),elbow,previous,end,membrane,.045)
                previous=end
                a.curve('Vein'+str(i),[elbow,tuple((x+y)/2 for x,y in zip(elbow,end)),end],.035,red if element=='Anti' else color)
            if element in ('Water','Wind'):
                for i in range(7):
                    a.p('Feather',p(2.5+i*.55,1-i*.22,.35),(.55,2.6-i*.16,.16),color,3,base.rotation(z=sign*-.6),288,.15)
            for x,y in [(2.5,2),(6.5,3.7)]:a.curve('Hook',[p(x,y,.3),p(x+.1,y+.6,.3),p(x-.2,y+.9,.3)],.1,color)
            a.finish()

def armor():
    for element,color in [('Bone',ivory),('Water',water),('Wind',wind),('Anti',dark)]:
        a=Asset(element+'ArmorUpperTorso')
        if element=='Bone':
            for i in range(6):
                y=.5-i*.19
                for sign in (-1,1):a.curve('Rib',[(sign*.1,y,-.63),(sign*.55,y-.06,-.75),(sign*.95,y-.2,-.43)],.075,ivory)
            for i in range(7):a.p('Spine',(0,.6-i*.2,.64),(.26,.2,.26),ivory,0)
            a.p('Heart',(0,.4,-.66),(.23,.23,.1),(247,246,255),0,material=288)
        else:
            a.p('Breastplate',(0,.05,-.58),(1.85,1.35,.2),color,material=1088 if element=='Anti' else 1568,alpha=.12 if element!='Anti' else 0)
            for sign in (-1,1):
                a.p('ChestFacet',(sign*.55,.17,-.75),(.8,1.2,.23),color,3,base.rotation(z=sign*-.25))
                for i in range(3):a.rod('Inlay',(sign*.12,.5-i*.3,-.8),(sign*.8,.1-i*.2,-.8),.025,red if element=='Anti' else gold)
        a.finish()
        a=Asset(element+'ArmorHead')
        if element in ('Bone','Anti'):
            for sign in (-1,1):
                a.curve('Horn',[(sign*.5,.5,.1),(sign*.85,1.1,.15),(sign*.8,1.8,.2),(sign*.48,2.05,0),(sign*.32,1.8,-.1)],.14,color)
                a.p('RedEye',(sign*.28,.03,-.63),(.24,.11,.05),red,0,material=288)
            a.p('Visor',(0,-.26,-.59),(1.2,.55,.06),dark)
        else:
            for i in range(5):a.p('Crown',((i-2)*.24,.6+(.2 if i==2 else 0),-.34),(.2,.55,.12),color,3,base.rotation(z=math.pi),288)
        a.finish()
        for body in ('LeftUpperArm','RightUpperArm','LeftLowerLeg','RightLowerLeg','LowerTorso'):
            a=Asset(element+'Armor'+body)
            leg='Leg' in body;lower=body=='LowerTorso';sign=-1 if body.startswith('Left') else 1
            if lower:
                for sign in (-1,1):
                    for i in range(3):a.p('HipPlate',(sign*(.35+i*.18),-.22-i*.12,-.57),(.45,.6,.15),color,3,base.rotation(z=sign*.45))
            else:
                a.p('Guard',(0,.1,-.46),(.92,1.05,.16),color,3)
                for i in range(3):
                    a.p('Layer',(0,.38-i*.3,-.54),(.96,.32,.14),color,3,base.rotation(z=math.pi))
                if not leg:
                    a.curve('ShoulderHorn',[(sign*.3,.45,0),(sign*.75,.9,.1),(sign*1.1,1.2,.15)],.12,color)
                    for i in range(3):a.p('BlackFringe',(sign*.43,-.1-i*.3,.05),(.3,.6,.7),dark,3,base.rotation(z=sign*.25))
            a.finish()

def creatures():
    a=Asset('Dragon')
    a.p('Cranium',(0,.4,0),(3.3,2.5,3.6),water,0,material=1568,alpha=.12)
    a.p('UpperMuzzle',(0,.05,-2.1),(2.35,1.2,3.2),water,3,base.rotation(y=math.pi),1568,.1)
    a.p('LowerJaw',(0,-1.05,-1.7),(2.3,.4,3.4),(55,144,210),3,base.rotation(y=math.pi))
    for sign in (-1,1):
        a.p('Eye',(sign*1.31,.65,-1.2),(.26,.3,.65),(230,252,255),0,material=288)
        a.curve('Horn',[(sign*1.2,1,.8),(sign*1.5,2.2,1.4),(sign*.8,3,2)],.2,(174,234,255))
        for i in range(5):a.p('Tooth',(sign*.85,-.62,-.4-i*.57),(.2,.65,.28),(232,250,255),3,base.rotation(z=math.pi))
        for i in range(3):a.p('CheekFin',(sign*(1.3+i*.2),.1+i*.3,.65+i*.4),(.4,1.6,.9),water,3,base.rotation(z=sign*-.6))
    for i in range(6):a.p('DorsalSpine',(0,1.4+i*.04,1+i*.5),(.4,1,1),water,3)
    a.finish()
    a=Asset('Hawk');a.p('Body',(0,0,0),(1.2,1.2,3),wind,0)
    a.p('Head',(0,.3,-1.55),(1,1,1.1),(218,255,227),0)
    a.p('Beak',(0,.05,-2.15),(.5,.55,.9),gold,3,base.rotation(y=math.pi))
    for sign in (-1,1):
        a.p('Eye',(sign*.43,.45,-1.7),(.13,.15,.3),gold,0,material=288)
        for i in range(6):a.p(('WingL_' if sign<0 else 'WingR_')+str(i),(sign*(1+i*.55),.2-i*.07,.2+i*.17),(.65,.16,2.5-i*.12),wind,3,base.rotation(y=sign*-.28))
    for i in range(3):a.p('Tail',((i-1)*.4,0,1.7),(.45,.12,1.7),(202,255,225),3)
    a.finish()
    a=Asset('BoneHand')
    for x in (-.6,.6):a.rod('Forearm',(x,0,.3),(x,5.5,0),.3,ivory,True)
    a.p('Palm',(0,6,0),(4.2,2,1.4),ivory,0)
    for i in range(5):
        x=(i-2)*.85
        a.curve('Finger'+str(i),[(x,6.5,0),(x*1.3,8.3,-.3),(x*1.2,9.4,-1.1),(x,8.8,-2)],.22,ivory)
    a.finish()

def golem():
    # Extend the existing R15 topology, keeping all 15 motors intact.
    doc=ET.parse(ROOT/'assets/Enemy.rbxmx').getroot();model=doc.find('Item')
    model.find("Properties/string[@name='Name']").text='Golem'
    parts={p.findtext("Properties/string[@name='Name']"):p for p in model.findall('Item') if p.attrib['class']=='Part'}
    for body in ('UpperTorso','LowerTorso','RightUpperArm','LeftUpperArm','RightHand','LeftHand','RightLowerLeg','LeftLowerLeg'):
        ref=parts[body];cf=ref.find("Properties/CoordinateFrame[@name='CFrame']")
        pos=tuple(float(cf.findtext(axis)) for axis in ('X','Y','Z'))
        for i in range(3):
            p=base.part(model,'RockPlate',add(pos,(0,.35-i*.3,-.52)),(1.1 if body!='UpperTorso' else 2.2,.5,.55),(92+i*8,109+i*5,103),800,base.rotation(z=(i-1)*.12),cls='WedgePart',anchored=False,collide=False)
            base.prop(p,'bool','Massless',True);base.weld(p,ref,p)
    core=base.part(model,'EmeraldCore',(0,4.13,-.7),(.65,.9,.35),(134,244,168),288,base.rotation(z=.4),cls='WedgePart',anchored=False,collide=False)
    base.prop(core,'bool','Massless',True);base.weld(core,parts['UpperTorso'],core)
    model.find("Item[@class='Humanoid']/Properties/string[@name='DisplayName']").text='Голем'
    # Imported asset referents must be unique within the expanded model.
    for i,node in enumerate(doc.iter('Item')):
        old=node.attrib['referent'];new='GOLEM'+str(i)
        for ref in doc.iter('Ref'):
            if ref.text==old:ref.text=new
        node.attrib['referent']=new
    ET.indent(doc);ET.ElementTree(doc).write(ROOT/'assets/Golem.rbxmx',encoding='utf-8',xml_declaration=True)

if __name__=='__main__':
    # Avoid referent collisions when extending the independently generated R15 file.
    base.counter=100000
    weapons();wings();armor();creatures();golem()
    (MESHES/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(f'Generated {len(manifest)} original model templates and OBJ/MTL pairs; extended existing R15 golem')
