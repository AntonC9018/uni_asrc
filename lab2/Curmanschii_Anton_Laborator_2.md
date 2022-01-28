# Laborator 2 la ASRC

A elaborat: **Curmanschii Anton, IA1901.**

Tema: **Securizarea routerului pentru acces administrativ.**


## Partea 1: Configurare de bază a dispozitivului de rețea


**Obiectivele:**

- Cablați rețeaua așa cum se arată în topologie. 
- Configurați adresarea IP de bază pentru routere și computere. 
- Configurați rutarea statică, inclusiv rutele implicite. 
- Verificați conectivitatea între gazde și routere. 

<style>
img[alt^="small"] 
{ 
    width: 400px;
}
</style>

![small Topologia](images/topology.png)

[DTE](https://www.wikiwand.com/en/Data_terminal_equipment),
[DCE](https://www.wikiwand.com/en/Data_circuit-terminating_equipment).


Am început cu routere și switch-uri vide (Empty).
Am adăugat la ele acele porturi de care avem nevoie pentru funcționarea corectă a sistemei.

- În R1 și în R3 am pus câte un modul **1CFE** (admite o singură conexiune Ethernet) și câte un modul **1SS** (admite o singură conexiune serială).
- În R2 am pus două module **1SS**.
- În switch-uri am pus câte 5 module **1FCE** (Fast Ethernet).

Am configurat toate dispozitivele. De exemplu, comenzile configurării routerului R3 arată astfel:

```
enable
configure terminal

interface FastEthernet0/0
ip address 192.168.3.1 255.255.255.0
no shutdown
exit

interface Serial1/0
ip address 10.2.2.2 255.255.255.252
no shutdown
exit
```

Configurarea statică a hosturilor PC-A și PC-C:

![](images/part1/PC-A_ip_config.png)
![](images/part1/PC-C_ip_config.png)


Putem deja verifica dacă există o conexiune între routere:


<!-- Pinging R2 from R1 -->

![](images/part1/ping_R1_to_R2.png)

```
Router#ping 10.1.1.1

Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 10.1.1.1, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 8/11/15 ms
```



![Pinging R3 from R2](images/part1/ping_R3_to_R2.png)

```
Router#ping 10.2.2.1

Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 10.2.2.1, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 7/12/15 ms
```



![Pinging from R3 to the other router](images/part1/ping_R3_to_other_routers.png)

```
Router>ping 10.1.1.2

Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 10.1.1.2, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 8/12/16 ms

Router>ping 10.2.2.2

Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 10.2.2.2, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 6/12/18 ms
```



<!-- Pinging R3 de la PC-C -->

![](images/part1/ping_PC-C_to_R3.png)

```
C:\>ping 192.168.3.1

Pinging 192.168.3.1 with 32 bytes of data:

Reply from 192.168.3.1: bytes=32 time<1ms TTL=255
Reply from 192.168.3.1: bytes=32 time<1ms TTL=255
Reply from 192.168.3.1: bytes=32 time<1ms TTL=255
Reply from 192.168.3.1: bytes=32 time<1ms TTL=255

Ping statistics for 192.168.3.1:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 0ms, Maximum = 0ms, Average = 0ms
```


<!-- Pinging R1 de la PC-A -->

![](images/part1/ping_PC-C_to_R3.png)

```
C:\>ping 192.168.1.1

Pinging 192.168.1.1 with 32 bytes of data:

Reply from 192.168.1.1: bytes=32 time<1ms TTL=255
Reply from 192.168.1.1: bytes=32 time<1ms TTL=255
Reply from 192.168.1.1: bytes=32 time<1ms TTL=255
Reply from 192.168.1.1: bytes=32 time<1ms TTL=255

Ping statistics for 192.168.1.1:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 0ms, Maximum = 0ms, Average = 0ms
```

Este clar că la această etapă încă nu putem face ping la celelalte rețele.
Pentru aceasta trebuie să configurăm rutele implicite.

Toate pachetele pe care R1 nu știe unde să le trimită, le vom trimite la R2.
Asemănător facem la R3.

La R1:

```
ip route 0.0.0.0 0.0.0.0 10.1.1.1
```

La R3:

```
ip route 0.0.0.0 0.0.0.0 10.2.2.1
```


La R2, configurăm subrețelele lor R1 și R3:

```
ip route 192.168.1.0 255.255.255.0 10.1.1.2
ip route 192.168.3.0 255.255.255.0 10.2.2.2
```


![](images/part1/ping_R1_R3_PC-C.png)

```
Router>ping 192.168.3.1

Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 192.168.3.1, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 12/20/24 ms

Router>ping 192.168.3.2

Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 192.168.3.2, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 3/12/18 ms
```



![](images/part1/ping_R3_R1_PC-A.png)

```
Router#ping 10.1.1.1

Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 10.1.1.1, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 8/11/13 ms

Router#ping 192.168.1.1

Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 192.168.1.1, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 15/22/27 ms

Router#ping 192.168.1.2

Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 192.168.1.2, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 10/14/22 ms
```


![](images/part1/ping_PC-A_to_PC-C.png)

```
C:\>ping 192.168.3.2

Pinging 192.168.3.2 with 32 bytes of data:

Reply from 192.168.3.2: bytes=32 time=25ms TTL=125
Reply from 192.168.3.2: bytes=32 time=14ms TTL=125
Reply from 192.168.3.2: bytes=32 time=13ms TTL=125
Reply from 192.168.3.2: bytes=32 time=2ms TTL=125

Ping statistics for 192.168.3.2:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 2ms, Maximum = 25ms, Average = 13ms
```


## Partea 2: Control acces administrativ pentru routere

**Obiectivele:**

- Configurați și criptați toate parolele. 
- Configurați un banner de avertizare de conectare. 
- Configurați securitatea îmbunătățită a parolei utilizatorului. 
- Configurați securitatea de conectare virtuală îmbunătățită. 
- Configurați un server SSH pe un router. 
- Configurați un client SSH și verificați conectivitatea. 


[Sintaxa enable password și enable secret](https://pediaa.com/what-is-the-difference-between-enable-password-and-enable-secret/).

[Diferența între enable password și enable secret, best practices](https://community.cisco.com/t5/networking-documents/understanding-the-differences-between-the-cisco-password-secret/ta-p/3163238).

[Comenzile de bază](https://w7cloud.com/packet-tracer-cisco-commands-list-cli-basic/).

[Despre nivelurile de privilegii](https://www.oreilly.com/library/view/hardening-cisco-routers/0596001665/ch04.html#hardcisco-CHP-4-SECT-7).

Deci, sumarizez:

- Se utilizează comanda `enable secret` pentru a pune parola la accesarea unui anumit nivel de privilegii al device-ului. 
  Implicit, routerele nu sunt parolate, adică pot fi accesate fără parolă.
- Există mai multe tipuri de stocare a parolelor, cele mai sigure metode fiind Type 6 care utilizează criptarea simetrică cu AES-128 cu o cheie master, sau Type 8 și Type 9 care folosesc funcții hash criptografice unidirecționale pe mai multe runde.
- `enable password` este o metodă deprecată de setarea parolelor.
- Routeri au 16 niveluri de privilegii cu permisiuni configurabile. 
  Implicit, sunt accesibile doar nivelurile 0, 1 și 15. 
  În Cisco Packet Tracer însă pare că nu putem accesa nivelul 0, deoarece accesul minim este 1.
  Poate fi că dacă punem parola la nivelul 1, îl vom putea accesa implicit.
  Folosim comanda `enable LEVEL_NUMBER` pentru a ne escala nivelul curent de privilegii la nivelul indicat.

Vom face cel mai simplu lucru — vom seta o singură parolă pentru nivelul de privilegii 15 la toate routere.
Este clar că trebuie să indicăm parole puternice într-un sistem real, însă aici ca să nu încurcăm parolele, vom pune parola simplă "1111".


Următoarea comandă setează parola 1111 la nivelul cel mai elevat de privilegii, utilizând metoda implicită de criptare (Type 5, SHA-256). [Documentația](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/security/d1/sec-d1-cr-book/sec-cr-e1.html#wp3438133060).

```
enable secret level 15 1111
```

Acum ne scoatem privilegiile, după ce ne intoarcem la nivelul privilegiat 15.
```
R1# disable

R1> enable
Password: 1111

R1# show privilege
Current privilege level is 15
```

Unica problema cu setarea tipului de stocare a parolelor (a tipului de criptare) este că trebuie să introducem parola deja criptată, ceea ce nu-i tare comod.
Pentru a seta o parolă cu o metodă de criptare specifică dar trebuie să folosim un program aparte, deoarece router-ul nu poate face acest lucru implicit, dintr-o oarecare cauză.
Probabil există o comandă care pur și simplu face criptarea, dar eu nu o pot găsi.

Deci în continuare setăm în modul indicat mai sus parole la toate routerele.

> Configurați un banner de avertizare de conectare.

<!-- [Informații despre Cisco Banner](https://www.manageengine.com/network-configuration-manager/configlets/configure-banner-cisco.html). -->

[Documentația](https://www.cisco.com/en/US/docs/ios/security/command/reference/sec_cr_book.pdf#page=380&zoom=auto,-91,718).

[Despre Telnet](https://www.wikiwand.com/en/Telnet). Telnet este un protocol de comunicare bidirecțională orientată pe text. Este un protocol veșnic, nesecurizat: mesajele sunt transmise în canal public și nu sunt criptate. A fost înlocuit cu [SSH](https://www.wikiwand.com/en/Secure_Shell). SSH criptează toate mesajele, protejând confidențialitatea comunicațiilor și datele sensitive.

Banner - este textul arătat utilizatorului când are loc o conectare la distanță de la host-ul utilizatorului la server.
În cazul nostru, router-ul joacă rolul serverului, iar unul din calculătoare este host.
De obicei pentru acest lucru se folosește protocolul SSH.
Deci înainte de a-l putea vedea pe acest banner setat, vom trebui să configurăm protocolul SSH pe router.

Am accesat informația din [acest document](https://www.cisco.com/c/dam/en/us/td/docs/ios/security/configuration/guide/12_4t/sec_12_4t_book.pdf) care dă instrucțiuni și informații exhaustive referitor la aceste lucruri.
[Ghid pentru implementarea securității cu parolele, login-urile pentru sesiunile CLI](https://www.cisco.com/c/dam/en/us/td/docs/ios/security/configuration/guide/12_4t/sec_12_4t_book.pdf#page=3075&zoom=180,65,616).

Pentru un test rapid vom configura Telnet, deoarece SSH trebuie mai mult setup.
Pentru a configura Telnet pentru sesiuni la distanță, folosesc următoarele comenzi:
```
R1> enable
R1# configure terminal
R1(config)# line vty 0 4
R1(config-line)# password 1111
R1(config-line)# end
```
<!-- [VTY (virtual teletype)](https://ipwithease.com/what-is-meaning-of-line-vty-0-4-in-configuration-of-cisco-router-or-switch/) este portul care permite aplicarea protocoalelor Telnet și SSH. -->

Următorul mesaj va fi arătat la login.

```
R1# configure terminal
R1(config)# banner login &Glad to see you here, user!&
```

Acum ne conectăm la router R1 de la calculator PC-C, folosind Telnet.

![small Deschidem aplicația Telnet / SSH Client](images/part2/telnet_ssh_client_application.png)

![Introducem adresa unei interfețe a routerului](images/part2/telnet_connection_configuration.png)

![Vedem banner-ul nostru](images/part2/telnet_login_banner.png)


> Configurați securitatea îmbunătățită a parolei utilizatorului.

Implicit, toate parolele sunt stocate în text clar (cu excepția parolei `enable secret`).
Un atacator ar putea să le găsească în rundown-ul configurării și să le fure:

```
R1> enable
Password: 1111
R1# show run | include password
no service password-encryption
 password 1111
```

Chiar dacă nu are parola de `enable secret`, poate descărca fișierul de configurație și poate să le găsescă în acel fișier, analizându-l cu un program.

Putem folosi serviciul `service password-encryption` pentru a cripta parolele.
Însă, acest serviciu folosește cifrul slab Vigenere care poate fi spart aproape imediat de un program specializat.
Iată, de exemplu, [cracker-ul oficial](https://www.firewall.cx/cisco-technical-knowledgebase/cisco-routers/358-cisco-type7-password-crack.html) produs de Cisco singuri.

```
R1# configure terminal
R1(config)# service password-encryption
R1(config)# end
```

Acum dacă arătăm `show run`, vedem că parola a fost cifrată cu metoda 7 (Vigenere).

```
R1# show run | include password
service password-encryption
 password 7 08701D1F58
```

Referitor la parolele utilizatorilor, acestea trebuie fi introduse deja criptate individual atunci când se crează parola, pe lângă tipul numeric al criptării.
Iarăși, cum s-a menționat anterior, această metodă nu este comodă, deoarece necesită criptarea aparte, cu toate este clar că poate fi realizată direct în router cu parola clară ca input.
Poate există o metodă, dar eu nu o pot găsi.

<!-- Presupun că putem schimba metoda aceasta în timpul setării acestei parole, dar pare că nu am dreptate.
```
R1#config termina
Enter configuration commands, one per line.  End with CNTL/Z.
R1(config)#line vty 0 4
R1(config-line)#no password
R1(config-line)#password ?
  7     Specifies a HIDDEN password will follow
  LINE  The UNENCRYPTED (cleartext) line password
R1(config-line)#password 1111
R1(config-line)#end
``` -->



## Partea 3: Configurarea rolurilor administrative 

**Obiectivele:**

- Creați vizualizări de roluri multiple și acordați privilegii diferite. 
- Verificați și contrastați opiniile. 


## Partea 4: Configurarea raportărilor de reziliență și management Cisco IOS

**Obiectivele:**

- Asigurați fișierele de imagine și configurare Cisco IOS. 
- Configurați un router ca sursă de timp sincronizată pentru alte dispozitive care utilizează NTP. 
- Configurați suportul Syslog pe un router. 
- Instalați un server Syslog pe un computer și activați-l. 
- Configurați raportarea capcanelor pe un router folosind SNMP.
- Efectuați modificări ale routerului și monitorizați rezultatele syslog-ului pe computer. 


## Partea 5: Configurarea funcțiilor de securitate automatizate 

**Obiectivele:**

- Blocați un router utilizând AutoSecure și verificați configurația. 
- Folosiți instrumentul Audit de securitate SDM pentru a identifica vulnerabilitățile și pentru a bloca serviciile. 
- Contrastați configurația AutoSecure cu SDM.
