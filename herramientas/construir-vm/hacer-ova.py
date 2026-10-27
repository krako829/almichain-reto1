#!/usr/bin/env python3
"""Almi-Chain · Empaqueta discos .raw en una OVA para VirtualBox
(OVF 1.0 + VMDK streamOptimized + manifiesto SHA256). Necesita qemu-img.

Uso: hacer-ova.py [--audio] NOMBRE memoria_MB cpus "descripción" disco1.raw [disco2.raw ...]
  --audio  añade una tarjeta de sonido (AC97; VirtualBox la importa como tal) — para la recreativa
La .ova se deja en la carpeta de la variable SALIDA (por defecto ./salida).

El OVF es el estándar, sin la sección propia de VirtualBox: no lleva controlador gráfico ni
memoria de vídeo, que VirtualBox pone por defecto según el tipo de sistema (Ubuntu 64-bit).
"""
import sys, os, subprocess, hashlib, tarfile, html

args = sys.argv[1:]
audio = '--audio' in args
args = [a for a in args if a != '--audio']
nombre, mem, cpus, desc = args[0], int(args[1]), int(args[2]), args[3]
raws = args[4:]
out = os.environ.get('SALIDA', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'salida'))
os.makedirs(out, exist_ok=True)
tmp = f'{out}/{nombre}.d'; os.makedirs(tmp, exist_ok=True)

vmdks = []
for i, r in enumerate(raws, 1):
    v = f'{nombre}-disk{i}.vmdk'
    subprocess.run(['qemu-img', 'convert', '-p', '-f', 'raw', '-O', 'vmdk', '-o', 'subformat=streamOptimized', r, f'{tmp}/{v}'], check=True)
    cap = os.path.getsize(r)
    vmdks.append((v, cap, os.path.getsize(f'{tmp}/{v}')))

refs = ''.join(f'    <File ovf:id="file{i}" ovf:href="{v}" ovf:size="{s}"/>\n' for i, (v, c, s) in enumerate(vmdks, 1))
disks = ''.join(f'    <Disk ovf:capacity="{c}" ovf:diskId="vmdisk{i}" ovf:fileRef="file{i}" ovf:format="http://www.vmware.com/interfaces/specifications/vmdk.html#streamOptimized"/>\n' for i, (v, c, s) in enumerate(vmdks, 1))
items = f'''      <Item>
        <rasd:Caption>{cpus} virtual CPU</rasd:Caption>
        <rasd:Description>Number of virtual CPUs</rasd:Description>
        <rasd:ElementName>{cpus} virtual CPU</rasd:ElementName>
        <rasd:InstanceID>1</rasd:InstanceID>
        <rasd:ResourceType>3</rasd:ResourceType>
        <rasd:VirtualQuantity>{cpus}</rasd:VirtualQuantity>
      </Item>
      <Item>
        <rasd:AllocationUnits>MegaBytes</rasd:AllocationUnits>
        <rasd:Caption>{mem} MB of memory</rasd:Caption>
        <rasd:Description>Memory Size</rasd:Description>
        <rasd:ElementName>{mem} MB of memory</rasd:ElementName>
        <rasd:InstanceID>2</rasd:InstanceID>
        <rasd:ResourceType>4</rasd:ResourceType>
        <rasd:VirtualQuantity>{mem}</rasd:VirtualQuantity>
      </Item>
      <Item>
        <rasd:Address>0</rasd:Address>
        <rasd:Caption>sataController0</rasd:Caption>
        <rasd:Description>SATA Controller</rasd:Description>
        <rasd:ElementName>sataController0</rasd:ElementName>
        <rasd:InstanceID>3</rasd:InstanceID>
        <rasd:ResourceSubType>AHCI</rasd:ResourceSubType>
        <rasd:ResourceType>20</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Caption>Ethernet adapter on 'NAT'</rasd:Caption>
        <rasd:Connection>NAT</rasd:Connection>
        <rasd:ElementName>Ethernet adapter on 'NAT'</rasd:ElementName>
        <rasd:InstanceID>4</rasd:InstanceID>
        <rasd:ResourceSubType>E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:Address>0</rasd:Address>
        <rasd:Caption>usb</rasd:Caption>
        <rasd:Description>USB Controller</rasd:Description>
        <rasd:ElementName>usb</rasd:ElementName>
        <rasd:InstanceID>5</rasd:InstanceID>
        <rasd:ResourceType>23</rasd:ResourceType>
      </Item>
'''
if audio:
    items += '''      <Item>
        <rasd:AddressOnParent>3</rasd:AddressOnParent>
        <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
        <rasd:Caption>sound</rasd:Caption>
        <rasd:Description>Sound Card</rasd:Description>
        <rasd:ElementName>sound</rasd:ElementName>
        <rasd:InstanceID>50</rasd:InstanceID>
        <rasd:ResourceSubType>ensoniq1371</rasd:ResourceSubType>
        <rasd:ResourceType>35</rasd:ResourceType>
      </Item>
'''
for i, (v, c, s) in enumerate(vmdks, 1):
    items += f'''      <Item>
        <rasd:AddressOnParent>{i-1}</rasd:AddressOnParent>
        <rasd:Caption>disk{i}</rasd:Caption>
        <rasd:Description>Disk Image</rasd:Description>
        <rasd:ElementName>disk{i}</rasd:ElementName>
        <rasd:HostResource>/disk/vmdisk{i}</rasd:HostResource>
        <rasd:InstanceID>{5+i}</rasd:InstanceID>
        <rasd:Parent>3</rasd:Parent>
        <rasd:ResourceType>17</rasd:ResourceType>
      </Item>
'''
ovf = f'''<?xml version="1.0"?>
<Envelope ovf:version="1.0" xml:lang="en-US" xmlns="http://schemas.dmtf.org/ovf/envelope/1" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:vbox="http://www.virtualbox.org/ovf/machine">
  <References>
{refs}  </References>
  <DiskSection>
    <Info>List of the virtual disks used in the package</Info>
{disks}  </DiskSection>
  <NetworkSection>
    <Info>Logical networks used in the package</Info>
    <Network ovf:name="NAT">
      <Description>Logical network used by this appliance.</Description>
    </Network>
  </NetworkSection>
  <VirtualSystem ovf:id="{nombre}">
    <Info>A virtual machine</Info>
    <ProductSection>
      <Info>Meta-information about the installed software</Info>
      <Product>{html.escape(nombre)}</Product>
      <Vendor>Almi-Chain · Reto 1 ASIR1</Vendor>
      <Version>1.0</Version>
    </ProductSection>
    <AnnotationSection>
      <Info>A human-readable annotation</Info>
      <Annotation>{html.escape(desc)}</Annotation>
    </AnnotationSection>
    <OperatingSystemSection ovf:id="94">
      <Info>The kind of installed guest operating system</Info>
      <Description>Ubuntu_64</Description>
      <vbox:OSType ovf:required="false">Ubuntu_64</vbox:OSType>
    </OperatingSystemSection>
    <VirtualHardwareSection>
      <Info>Virtual hardware requirements for a virtual machine</Info>
      <System>
        <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
        <vssd:InstanceID>0</vssd:InstanceID>
        <vssd:VirtualSystemIdentifier>{nombre}</vssd:VirtualSystemIdentifier>
        <vssd:VirtualSystemType>virtualbox-2.2</vssd:VirtualSystemType>
      </System>
{items}    </VirtualHardwareSection>
  </VirtualSystem>
</Envelope>
'''
open(f'{tmp}/{nombre}.ovf', 'w').write(ovf)

def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''): h.update(b)
    return h.hexdigest()
files = [f'{nombre}.ovf'] + [v for v, c, s in vmdks]
open(f'{tmp}/{nombre}.mf', 'w').write(''.join(f'SHA256({f})= {sha(f"{tmp}/{f}")}\n' for f in files))
ova = f'{out}/{nombre}.ova'
with tarfile.open(ova, 'w', format=tarfile.USTAR_FORMAT) as t:
    for f in [f'{nombre}.ovf', f'{nombre}.mf'] + [v for v, c, s in vmdks]:
        ti = t.gettarinfo(f'{tmp}/{f}', arcname=f); ti.uid = ti.gid = 0; ti.uname = ti.gname = ''; ti.mode = 0o644
        with open(f'{tmp}/{f}', 'rb') as fh: t.addfile(ti, fh)
for f in os.listdir(tmp): os.remove(f'{tmp}/{f}')
os.rmdir(tmp)
print(ova, os.path.getsize(ova) // (1024 * 1024), 'MB')
