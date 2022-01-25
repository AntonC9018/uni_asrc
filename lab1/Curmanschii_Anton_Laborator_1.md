# Laborator 1 la ASRC

A elaborat: **Curmanschii Anton, IA1901.**

Tema: **Cercetarea atacurilor din rețea și instrumente de audit de securitate.**


## Obiective

*Partea 1*: Cercetarea atacurilor din rețea

1. Atacuri în rețeaua de cercetare care au avut loc. 
2. Selectați un atac de rețea și elaborați un raport pentru prezentare la laborator.

*Partea 2*: Cercetarea instrumentelor de audit de securitate

1. Instrumente de audit al securității rețelei de cercetare. 
2. Selectați un instrument și elaborați un raport pentru prezentare la laborator.


## Partea 1.1: Cercetarea atacurilor din rețea

### Introducere

Un **atac de rețea** este o încercare de a obține acces neautorizat la rețeaua unei organizații, cu scopul de a fura date sau de a efectua alte activități rău intenționate.
Există două tipuri principale de atacuri de rețea:

- **Pasive**. Atacatorii monitorizează rețeaua compromisă, furând datele, dar fără a modifica cu datele care trec prin rețea.
- **Active**. Atacatorii nu doar obțin accesul la o rețea, dar și modific datele care trec prin ea.

Este clar că atacurile pasive sunt șpionaj și este mai dificil de a se da seama de ele, pe când atacurile active sunt de obicei mai destructive pentru infrastructura rețelei.

În cazul unui atac de rețea, atacatorii se concentrează pe penetrarea perimetrului rețelei corporative și pe obținerea accesului la sistemele interne. 
De obicei, odată ce obțin acces la interiorul rețelei, atacatorii vor combina alte tipuri de atacuri, 
de exemplu răspândirea de programe malware sau exploatarea unei vulnerabilități a unui sistem din cadrul rețelei.


### Modalitățile comune de pătrungere în rețea

1. **Accesul neautorizat.**
   Accesul neautorizat se referă la atacatorii care accesează o rețea fără a primi permisiunea. 
   Cauzele: parolele slabe, parolele prea complicate sau un număr abundant de ele, pe care utilizatorii rețelei le păstrez în textul clar, deoarece nu le pot memora, adică le notează pe hârtie, sau într-un document textual; lipsa protecției împotriva ingineriei sociale sau lipsa conștientizării importanței securității organizației; conturile compromise anterior.

2. **Atacurile de negare distribuită a serviciului (DDoS - Distributed Denial of Service).**
   Atacatorii construiesc botnet-uri (volume mari de dispozitive zombie) și le folosesc pentru a direcționa trafic fals către rețeaua sau serverele unei organizației. 
   DDoS poate avea loc la nivel de rețea, de exemplu prin trimiterea unor volume uriașe de pachete SYN/ACC (TCP) care pot copleși un server, 
   sau la nivel de aplicație, de exemplu prin efectuarea de interogări SQL complexe care pot înăbuși baza de date.

3. **Atacurile de tip "Man in the middle".**
   Un atac de tip "man in the middle" presupune ca atacatorii să intercepteze traficul, fie dintre rețeaua organizației și exteriorul rețelei, fie din interiorul rețelei. 
   Dacă protocoalele de comunicare nu sunt securizate sau dacă atacatorii găsesc o modalitate de a ocoli această securitate, ei pot fura datele care sunt transmise, obține datele personale ale utilizatorilor și pot să le impersoneze, deturnând sesiunile acestora.

4. **Atacuri de injecție de cod și SQL.**
   Unele site-uri web acceptă input de la utilizatori fără a-l valida adecvat.
   Atacatorii pot completa un formular sau să facă un apel API, trecând cod malițios în locul valorilor de date așteptate.
   Codul este executat pe server și permite atacatorilor să-l compromită.
   O altă posibilitate de atac de acest fel este atacul buffer overflow care tot permite executarea codului propriu, cu toate că este și mai complexă de exploatat.

5. **Amenințările din interior.**
   O rețea este deosebit de vulnerabilă în fața persoanelor rău intenționate din interior, care au deja acces privilegiat la sistemele organizației.
   Amenințările din interior pot fi dificil de detectat și de protejat, deoarece persoanele din interior sunt de obicei încrezute.
   Unele tehnologii noi pot ajuta la identificarea comportamentelor suspecte sau anormale.
   Un administrator de obicei însă are acces la toate resursele rețelei și dacă este compromis sau rău intenționat, poate distruge integritatea întregii rețele.


## Partea 1.2: Injecția SQL

Injecția SQL (SQL Injection, sau SQLI) a fost considerată una dintre cele mai importante 10 vulnerabilități ale aplicațiilor web din 2007 și 2010 de către Open Web Application Security Project. 
În 2013, SQLI a fost considerată atacul numărul unu în topul OWASP.

### Interogările SQL contstruite inadecvat

Acest mod de atac este bazat pe exploatarea faptului că datele în interogările SQL sunt combinate cu logică.
Următorul exemplu selectează toți utilizatorii, unde numele este 'Anton':

```sql
select * from Users
where name = 'Anton'
```

Ne putem imagina că aplicația este programată în așa fel ca să admite input-ul din partea utilizatorului pentru construirea acestui șir al interogării. 
În alte cuvinte, utilizatorul introduce un șir și se face un `format` pe baza șablonului de interogare pentru a constui interogarea finală.
Urmează codul aproximativ:

```d
void DoUserQuery()
{
    string queryTemplate = "select * form Users where name = '%s'";
    string name          = getUserInput();
    string queryString   = format(queryTemplate, name);
    QueryResult results  = executeQuery(queryString);
    sendResultsToUser(results);
}
```

Deci dacă utilizatorul dă input-ul "Anton", primim interogarea `select * from Users where name = 'Anton'` — informația despre utilizatorul cu numele "Anton".

Ce ar întâmpla, dacă utilizatorul dă `' or '1'='1`?
Formatând șirul șablon cu `' or '1'='1` ca numele, vom primi interogarea `select * from where name = '' or '1'='1'`.
Această interogare ar afișa la utilizator întregul tabel `Users`, deoarece `'1'='1'` mereu dă `true`.

În acest caz, o validare minimă ar putea lucra: de exemplu să admitem doar literele A-Z și a-z, dar poate există numile într-o altă limbă, de exemplu, scrise cu literele rusește, sau cu cratime înăuntru?
(Se mai poate face un fel de escape la toate caractere care ar avea o semnificație specială în SQL, de exemplu escape-ul lui ' la '')
Deci validarea va fi strâns legată la domeniul de valori al câmpului `name`, și trebuie să fie efectuată cât mai strict, și pe frontend, și pe backend.
Validarea pe frontend este necesară pentru a nu se încarce serverul fără rost, iar validarea pe backend este necesară pentru prevenirea exploatărilor.
*Never trust the user input!*

### Injectarea SQL oarbă 

Injectarea SQL oarbă înseamnă injectarea SQL, unde atacatorul nu vede direct rezultatele interogărilor.
Un exemplu ar fi o pagină web care arată datele diferit în funcția de dacă interogarea SQL a fost legitimă și s-a acceptat, sau dacă nu.
Deoarece hacker-ul ar primi un singur bit de informație de fiecare dată (în condiții simple), metoda aceasta este considerată lentă.
Există instumente care permit automatizarea spargerii de așa sisteme prin injectarea codurilor SQL selectate minuțios.

Exemplu: o pagină web poate arăta informații despre cărți după un anumit identificator, primit ca parametru în URL.
De exemplu `https://books.example.com/bookinfo?id=2` ar executa interogarea SQL `select * from BookInfo where id=2`, și utilizatorul ar vedea informații despre carte sugerată în cazul în care interogare reușește.
Acum, hacker-ul dă `https://books.example.com/bookinfo?id=2 and 1=1`, de unde serverul extrage că id-ul este `2 and 1=1` și construiește interogarea `select * from BookInfo where id=5 and 1=1`.
Dacă pagina arată ca rezultat informații despre o altă carte, atunci șirul cerut de el a trecut validarea cu succes și serverul este vulnerabil la injecții SQL.

Acum atacatorul poate de exemplu folosi interogări mai complexe pentru a afla mai multe informații despre server.
De exemplu, atacatorul poate face un binary search pe versiuni, utilizând URL-ul `https://books.example.com/bookinfo?id=5 and substring(@@version, 1, INSTR(@@version, '.') - 1)<X`, unde X să fie un număr întreg. 


### Injecție SQL de ordinul 2

Injecția SQL de ordinul doi apare atunci când valorile trimise conțin comenzi malițioase care sunt stocate în loc de a fi executate imediat. 
În unele cazuri, este posibil ca aplicația să codifice corect o instrucțiune SQL și s-o stocheze ca fiind SQL valid.
Apoi, o altă parte a aplicației care nu dispune de controale de protecție împotriva injecției SQL ar putea executa acea instrucțiune SQL stocată.
Acest atac necesită mai multe cunoștințe despre modul în care valorile trimise sunt utilizate ulterior.
Scanerele automate de securitate a aplicațiilor web nu ar putea detecta cu ușurință acest tip de injecție SQL și ar putea fi nevoie să fie instruite manual unde să verifice dacă există dovezi că se încearcă acest lucru. 

### Mitigarea

- Una din metode este escaping al parametrilor, care deja s-a menționat.
  Însă nu este o soluție bună, deoarece este ușor să uitați să aplicați funcția care face escape la parametri.
- Regex-uri sau alți validări de domeniu manuale.
- Object Relational Mappers (ORM) abstractizează codul SQL cu totul și de obicei validează parametrile automat.
- Să se utlizeze altceva decât șiruri pentru parametrizarea interogărilor.


### Exemplele

Vedeți o listă de exemple [aici](https://www.wikiwand.com/en/SQL_injection#/Examples).

## Bibliografia

Am interpretat informația despre SQL Injection de pe [wiki](https://www.wikiwand.com/en/SQL_injection).
