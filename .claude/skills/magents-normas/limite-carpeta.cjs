#!/usr/bin/env node
// Hook PreToolUse de los agentes de magents: bloquea lo que salga de la raíz del proyecto.
// Es una barrera ante errores, no un aislamiento: no ve lo que haga el código PHP o JS al ejecutarse,
// ni lo que hagan los scripts de .magents/scripts/. Ante la duda, bloquea.
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');

const ARCHIVO_RUTAS = '.magents/rutas-autorizadas.txt';
const HOME = os.homedir();
// Nunca se modifican, aunque haya una ruta autorizada.
const CRITICAS = ['/bin', '/boot', '/dev', '/etc', '/lib', '/lib32', '/lib64', '/proc', '/root', '/run', '/sbin', '/sys', '/usr', '/var'];
const EJECUTABLES = ['/bin', '/sbin', '/usr/bin', '/usr/sbin', '/usr/local/bin'];
const SALIDAS_INOFENSIVAS = new Set(['/dev/null', '/dev/stdout', '/dev/stderr', '/dev/tty']);

const PROHIBIDOS = new Set(['sudo', 'su', 'doas', 'pkexec', 'fdisk', 'parted', 'shutdown', 'reboot', 'halt', 'poweroff',
  'systemctl', 'service', 'mount', 'umount', 'pkill', 'killall', 'crontab', 'useradd', 'userdel', 'usermod', 'passwd',
  'iptables', 'nft', 'chroot', 'eval']);
const MODIFICAN = new Set(['rm', 'rmdir', 'unlink', 'shred', 'mv', 'cp', 'ln', 'chmod', 'chown', 'chgrp', 'touch', 'mkdir',
  'tee', 'truncate', 'dd', 'rsync', 'install', 'mkfifo']);
const LEEN = new Set(['cat', 'less', 'more', 'head', 'tail', 'ls', 'du', 'stat', 'file', 'wc', 'grep', 'egrep', 'fgrep', 'rg',
  'sed', 'awk', 'sort', 'uniq', 'cut', 'diff', 'cmp', 'sha256sum', 'sha1sum', 'md5sum', 'tar', 'zip', 'unzip', 'gzip', 'gunzip',
  'base64', 'realpath', 'readlink', 'tree', 'xxd', 'od', 'nl', 'tac', 'strings', 'source', '.', 'cd', 'pushd', 'bash', 'sh', 'zsh', 'dash',
  'php', 'python', 'python3', 'node', 'perl', 'ruby']);
const ENVOLTORIOS = new Set(['env', 'command', 'exec', 'nohup', 'nice', 'timeout', 'stdbuf', 'time', 'ionice', 'builtin']);
// Cambian el daemon, el proyecto o el archivo sobre el que actúan docker y docker compose.
const VARIABLES_DOCKER = /^(DOCKER_HOST|DOCKER_CONTEXT|DOCKER_CONFIG|COMPOSE_PROJECT_NAME|COMPOSE_FILE|COMPOSE_PATH_SEPARATOR)=/;
const CLAVES = new Set(['if', 'then', 'elif', 'else', 'fi', 'for', 'while', 'until', 'do', 'done', 'case', 'esac', '!', '{', '}', 'function']);
const CON_PATRON = new Set(['grep', 'egrep', 'fgrep', 'rg', 'sed', 'awk']);
const CON_CODIGO = { php: '-r', node: '-e', python: '-c', python3: '-c', perl: '-e', ruby: '-e' };
const INTERPRETES = new Set(['bash', 'sh', 'zsh', 'dash']);

class Bloqueo extends Error {}
function bloquea(motivo) {
  throw new Bloqueo(motivo);
}

function real(ruta) {
  let actual = ruta;
  const resto = [];
  for (;;) {
    try {
      return path.join(fs.realpathSync(actual), ...resto);
    } catch {
      const padre = path.dirname(actual);
      if (padre === actual) return ruta;
      resto.unshift(path.basename(actual));
      actual = padre;
    }
  }
}

function dentroDe(ruta, base) {
  return ruta === base || ruta.startsWith(base === '/' ? '/' : base + '/');
}

// Parte un comando en órdenes simples. No es un intérprete completo: lo que no entiende se marca como dinámico.
// NOMBRE=valor solo es asignación si NOMBRE= está escrito sin comillas ni partes calculadas; el valor puede llevarlas.
function esAsignacion(palabra) {
  const m = palabra.texto.match(/^[A-Za-z_][A-Za-z0-9_]*=/);
  return Boolean(m) && m[0].length <= palabra.literal;
}

function analizarSintaxis(texto, variables) {
  const ordenes = [];
  const internos = [];
  let orden = { palabras: [], redirecciones: [] };
  let palabra = null;
  let redireccion = null;
  const heredocs = [];
  let i = 0;

  // literal: hasta dónde el texto de la palabra es literal, sin comillas ni partes calculadas (para reconocer NOMBRE=valor).
  const nueva = () => { if (!palabra) palabra = { texto: '', dinamica: false, entrecomillada: false, literal: Infinity }; };
  const finLiteral = () => { if (palabra.literal === Infinity) palabra.literal = palabra.texto.length; };
  const cerrarPalabra = () => {
    if (!palabra) return;
    if (redireccion) {
      if (redireccion !== 'cadena') orden.redirecciones.push({ tipo: redireccion, destino: palabra });
      redireccion = null;
    } else {
      orden.palabras.push(palabra);
    }
    palabra = null;
  };
  const cerrarOrden = () => {
    cerrarPalabra();
    if (orden.palabras.length || orden.redirecciones.length) ordenes.push(orden);
    orden = { palabras: [], redirecciones: [] };
  };
  const leerAnidado = (abre, cierra, desde) => {
    let nivel = 1;
    let j = desde;
    while (j < texto.length && nivel > 0) {
      if (texto[j] === '\\') j += 1;
      else if (texto[j] === abre) nivel += 1;
      else if (texto[j] === cierra) nivel -= 1;
      j += 1;
    }
    if (nivel !== 0) bloquea('no se puede interpretar el comando: paréntesis sin cerrar');
    return j;
  };
  const leerDolar = () => {
    nueva();
    if (texto[i + 1] === '(' && texto[i + 2] !== '(') {
      const fin = leerAnidado('(', ')', i + 2);
      internos.push(texto.slice(i + 2, fin - 1));
      finLiteral();
      palabra.dinamica = true;
      i = fin;
      return;
    }
    if (texto[i + 1] === '(') {
      i = leerAnidado('(', ')', i + 2);
      finLiteral();
      palabra.texto += '0';
      return;
    }
    const llaves = texto.slice(i).match(/^\$\{([A-Za-z_][A-Za-z0-9_]*)\}/);
    const simple = texto.slice(i).match(/^\$([A-Za-z_][A-Za-z0-9_]*)/);
    const coincide = llaves || simple;
    if (coincide) {
      finLiteral();
      if (Object.prototype.hasOwnProperty.call(variables, coincide[1])) palabra.texto += variables[coincide[1]];
      else palabra.dinamica = true;
      i += coincide[0].length;
      return;
    }
    if (texto[i + 1] === '{') {
      const fin = leerAnidado('{', '}', i + 2);
      finLiteral();
      palabra.dinamica = true;
      i = fin;
      return;
    }
    if (/[?#@*!$0-9-]/.test(texto[i + 1] || '')) {
      finLiteral();
      palabra.dinamica = true;
      i += 2;
      return;
    }
    palabra.texto += '$';
    i += 1;
  };
  const leerAcento = () => {
    nueva();
    const fin = texto.indexOf('`', i + 1);
    if (fin < 0) bloquea('no se puede interpretar el comando: comilla invertida sin cerrar');
    internos.push(texto.slice(i + 1, fin));
    finLiteral();
    palabra.dinamica = true;
    i = fin + 1;
  };

  while (i < texto.length) {
    const c = texto[i];
    if (c === '\n') {
      cerrarOrden();
      i += 1;
      for (const h of heredocs.splice(0)) {
        for (;;) {
          if (i >= texto.length) break;
          let fin = texto.indexOf('\n', i);
          if (fin < 0) fin = texto.length;
          const linea = texto.slice(i, fin);
          i = fin + 1;
          if ((h.quitarTabs ? linea.replace(/^\t+/, '') : linea) === h.fin) break;
        }
      }
    } else if (c === ' ' || c === '\t') {
      cerrarPalabra();
      i += 1;
    } else if (c === '#' && !palabra) {
      while (i < texto.length && texto[i] !== '\n') i += 1;
    } else if (c === '\\') {
      if (texto[i + 1] === '\n') {
        i += 2;
      } else {
        nueva();
        finLiteral();
        palabra.texto += texto[i + 1] || '';
        palabra.entrecomillada = true;
        i += 2;
      }
    } else if (c === "'") {
      nueva();
      const fin = texto.indexOf("'", i + 1);
      if (fin < 0) bloquea('no se puede interpretar el comando: comilla sin cerrar');
      finLiteral();
      palabra.texto += texto.slice(i + 1, fin);
      palabra.entrecomillada = true;
      i = fin + 1;
    } else if (c === '"') {
      nueva();
      finLiteral();
      palabra.entrecomillada = true;
      i += 1;
      while (i < texto.length && texto[i] !== '"') {
        if (texto[i] === '\\') {
          palabra.texto += texto[i + 1] || '';
          i += 2;
        } else if (texto[i] === '$') {
          leerDolar();
        } else if (texto[i] === '`') {
          leerAcento();
        } else {
          palabra.texto += texto[i];
          i += 1;
        }
      }
      if (i >= texto.length) bloquea('no se puede interpretar el comando: comilla sin cerrar');
      i += 1;
    } else if (c === '$') {
      leerDolar();
    } else if (c === '`') {
      leerAcento();
    } else if (c === '<' && texto[i + 1] === '(' || c === '>' && texto[i + 1] === '(') {
      const fin = leerAnidado('(', ')', i + 2);
      internos.push(texto.slice(i + 2, fin - 1));
      i = fin;
    } else if (c === '<' || c === '>') {
      if (palabra && /^\d+$/.test(palabra.texto) && !palabra.entrecomillada) palabra = null;
      else if (palabra && palabra.texto === '&') palabra = null;
      else cerrarPalabra();
      if (texto.startsWith('<<<', i)) {
        redireccion = 'cadena';
        i += 3;
      } else if (texto.startsWith('<<', i)) {
        i += 2;
        const quitarTabs = texto[i] === '-';
        if (quitarTabs) i += 1;
        const delimitador = texto.slice(i).match(/^\s*(?:'([^']*)'|"([^"]*)"|\\?([^\s;&|<>()]+))/);
        if (!delimitador) bloquea('no se puede interpretar el comando: heredoc sin delimitador');
        heredocs.push({ fin: delimitador[1] ?? delimitador[2] ?? delimitador[3], quitarTabs });
        i += delimitador[0].length;
      } else if (texto[i + 1] === '&' && /[\d-]/.test(texto[i + 2] || '')) {
        i += 3;
        while (/\d/.test(texto[i] || '')) i += 1;
      } else {
        redireccion = c === '>' ? 'escribe' : 'lee';
        i += 1;
        if (texto[i] === '>' || texto[i] === '|') i += 1;
      }
    } else if (c === '&' && texto[i + 1] === '>') {
      cerrarPalabra();
      redireccion = 'escribe';
      i += 2;
      if (texto[i] === '>') i += 1;
    } else if (';|&()'.includes(c)) {
      cerrarOrden();
      i += 1;
    } else {
      nueva();
      if (c === '~' && palabra.texto === '' && !palabra.entrecomillada && /^(~$|~\/|~[\s;|&)])/.test(texto.slice(i) + ' ')) palabra.texto += HOME;
      else palabra.texto += c;
      i += 1;
    }
  }
  cerrarOrden();
  return { ordenes, internos };
}

class Analizador {
  constructor(raiz, cwd, autorizadas) {
    this.raiz = raiz;
    this.cwd = cwd;
    this.cwdConocido = true;
    this.autorizadas = autorizadas;
    this.profundidad = 0;
  }

  resolver(ruta, cwd = this.cwd) {
    const sinComodines = ruta.replace(/[*?[].*$/, '');
    return real(path.resolve(cwd, sinComodines || '.'));
  }

  dentro(ruta) {
    return dentroDe(ruta, this.raiz) || this.autorizadas.some((base) => dentroDe(ruta, base));
  }

  lecturaPermitida(ruta) {
    return this.dentro(ruta)
      || /^\/tmp\/claude-[^/]+\/.*\/(tasks|tool-results)(\/|$)/.test(ruta)
      || dentroDe(ruta, path.join(HOME, '.claude/projects')) && /\/(tasks|tool-results)(\/|$)/.test(ruta);
  }

  comprobarLectura(texto) {
    const ruta = this.resolver(texto);
    if (ruta === '/dev/urandom' || ruta === '/dev/zero' || ruta === '/dev/stdin' || SALIDAS_INOFENSIVAS.has(ruta)) return;
    if (!this.lecturaPermitida(ruta)) bloquea(`la ruta ${ruta} está fuera de la raíz del proyecto`);
  }

  comprobarEscritura(texto, salidaInofensiva = false) {
    const ruta = this.resolver(texto);
    if (salidaInofensiva && (SALIDAS_INOFENSIVAS.has(ruta) || /^\/dev\/fd\/\d+$/.test(ruta))) return;
    if (ruta === '/' || CRITICAS.some((base) => dentroDe(ruta, base)) || ruta === HOME || dentroDe(HOME, ruta)) {
      bloquea(`no se puede modificar ${ruta}: es una ruta del sistema`);
    }
    if (!this.dentro(ruta)) bloquea(`la ruta ${ruta} está fuera de la raíz del proyecto`);
    if (ruta === this.raiz) bloquea('no se puede modificar la raíz del proyecto entera');
    for (const protegida of ['.git', '.claude']) {
      if (dentroDe(ruta, path.join(this.raiz, protegida))) bloquea(`no se puede modificar ${protegida}/`);
    }
    if (ruta === path.join(this.raiz, ARCHIVO_RUTAS)) bloquea(`${ARCHIVO_RUTAS} solo lo edita el usuario`);
  }

  comprobarDinamica(palabra, verbo) {
    if (palabra.dinamica) {
      bloquea(`${verbo} con una ruta calculada (variable o $(...)) no se puede verificar; escribe la ruta exacta en una orden simple`);
    }
    if (!this.cwdConocido && !path.isAbsolute(palabra.texto)) {
      bloquea(`${verbo} con ruta relativa tras un cd que no se puede verificar; usa la ruta absoluta`);
    }
  }

  analizar(texto) {
    this.profundidad += 1;
    if (this.profundidad > 8) bloquea('comando demasiado anidado para verificarlo');
    if (texto.includes('rutas-autorizadas')) bloquea(`${ARCHIVO_RUTAS} solo lo edita el usuario`);
    const { ordenes, internos } = analizarSintaxis(texto, {
      PWD: this.cwd,
      CLAUDE_PROJECT_DIR: this.raiz,
      HOME,
    });
    for (const orden of ordenes) this.orden(orden);
    for (const interno of internos) this.analizar(interno);
    this.profundidad -= 1;
  }

  orden(orden) {
    let palabras = orden.palabras.slice();
    while (palabras.length && (esAsignacion(palabras[0]) || (!palabras[0].entrecomillada && CLAVES.has(palabras[0].texto)))) {
      if (VARIABLES_DOCKER.test(palabras[0].texto)) bloquea(`${palabras[0].texto.split('=')[0]} cambia el destino de docker y no está permitido`);
      palabras.shift();
    }
    if (palabras.length && ENVOLTORIOS.has(palabras[0].texto)) {
      const envoltorio = palabras.shift().texto;
      if (palabras.some((p) => VARIABLES_DOCKER.test(p.texto))) bloquea('esa variable cambia el destino de docker y no está permitido');
      while (palabras.length && (/^-/.test(palabras[0].texto) || esAsignacion(palabras[0])
        || (envoltorio === 'timeout' && /^\d/.test(palabras[0].texto)))) palabras.shift();
      this.orden({ palabras, redirecciones: orden.redirecciones });
      return;
    }
    const enDocker = palabras.length > 0 && path.basename(palabras[0].texto) === 'docker';
    for (const r of orden.redirecciones) {
      if (r.tipo === 'escribe') {
        this.comprobarDinamica(r.destino, 'Una redirección');
        this.comprobarEscritura(r.destino.texto, true);
      } else if (!r.destino.dinamica) {
        this.comprobarLectura(r.destino.texto);
      }
    }
    if (!palabras.length) return;
    if (palabras[0].dinamica) bloquea('el comando a ejecutar sale de una variable y no se puede verificar');

    let nombre = palabras[0].texto;
    const argumentos = palabras.slice(1);
    if (nombre.includes('/')) {
      const ruta = this.resolver(nombre);
      if (!this.dentro(ruta) && !EJECUTABLES.some((base) => dentroDe(ruta, base))) {
        bloquea(`no se puede ejecutar ${ruta}: está fuera de la raíz del proyecto`);
      }
      this.revisarScript(ruta);
      nombre = path.basename(nombre);
    }
    if (PROHIBIDOS.has(nombre) || /^mkfs/.test(nombre)) bloquea(`${nombre} no está permitido`);
    if (enDocker) return this.docker(argumentos);
    if (nombre === 'git') return this.git(argumentos);
    if (nombre === 'curl' || nombre === 'wget') return this.descarga(nombre, argumentos);
    if (nombre === 'find') return this.find(argumentos);
    if (nombre === 'xargs') return this.xargs(argumentos);
    if (nombre === 'ip') {
      if (argumentos.some((a) => /^(add|del|delete|set|flush|replace|change)$/.test(a.texto))) bloquea('ip solo se puede usar para consultar');
      return undefined;
    }
    if (nombre === 'dd') {
      for (const a of argumentos) {
        const m = a.texto.match(/^(if|of)=(.*)$/);
        if (!m) continue;
        this.comprobarDinamica(a, 'dd');
        if (m[1] === 'of') this.comprobarEscritura(m[2], true);
        else this.comprobarLectura(m[2]);
      }
      return undefined;
    }
    if (MODIFICAN.has(nombre)) return this.modifica(nombre, argumentos);
    if (nombre === 'sed' && argumentos.some((a) => /^(-[a-zA-Z]*i|--in-place)/.test(a.texto))) return this.modifica('sed -i', argumentos.slice(1));
    if (LEEN.has(nombre)) return this.lee(nombre, argumentos);
    return undefined;
  }

  revisarScript(ruta) {
    if (!dentroDe(ruta, this.raiz) || dentroDe(ruta, path.join(this.raiz, '.magents/scripts'))) return;
    let contenido;
    try {
      if (fs.statSync(ruta).size > 500000) return;
      contenido = fs.readFileSync(ruta, 'utf8');
    } catch {
      return;
    }
    if (/^#!.*\b(ba|z|da)?sh\b/.test(contenido) || /\.sh$/.test(ruta)) {
      const copia = new Analizador(this.raiz, this.cwd, this.autorizadas);
      copia.profundidad = this.profundidad;
      copia.analizar(contenido);
    }
  }

  posicionales(argumentos) {
    const lista = [];
    let soloRutas = false;
    for (const a of argumentos) {
      if (soloRutas) {
        lista.push(a);
      } else if (a.texto === '--') {
        soloRutas = true;
      } else if (a.texto.startsWith('-') && !a.dinamica) {
        const igual = a.texto.match(/^--?[^=]+=(.+)$/);
        if (igual) lista.push({ ...a, texto: igual[1] });
      } else {
        lista.push(a);
      }
    }
    return lista;
  }

  modifica(verbo, argumentos) {
    // cp, rsync, install y ln solo escriben en el destino: el resto de rutas se leen.
    if (/^(cp|rsync|install|ln)$/.test(verbo)) {
      let destino = null;
      const resto = [];
      for (let i = 0; i < argumentos.length; i += 1) {
        const a = argumentos[i];
        const pegado = a.texto.match(/^--target-directory=(.+)$/);
        if (pegado) destino = { ...a, texto: pegado[1] };
        else if (a.texto === '-t' && argumentos[i + 1]) destino = argumentos[(i += 1)];
        else resto.push(a);
      }
      const lista = this.posicionales(resto);
      if (!destino) destino = lista.pop();
      for (const a of lista) {
        if (verbo === 'rsync' && /^[^/]*:/.test(a.texto)) bloquea('rsync a otra máquina no está permitido');
        if (!a.dinamica) this.comprobarLectura(a.texto);
      }
      if (destino) {
        this.comprobarDinamica(destino, verbo);
        if (verbo === 'rsync' && /^[^/]*:/.test(destino.texto)) bloquea('rsync a otra máquina no está permitido');
        this.comprobarEscritura(destino.texto, verbo === 'cp');
      }
      return;
    }
    const lista = this.posicionales(argumentos);
    const destinoInofensivo = verbo === 'tee' || verbo === 'cp';
    // El primer argumento de chmod, chown y chgrp es el modo o el dueño.
    const rutas = /^(chmod|chown|chgrp)$/.test(verbo) ? lista.slice(1) : lista;
    for (const a of rutas) {
      this.comprobarDinamica(a, verbo);
      if (verbo === 'rsync' && /^[^/]*:/.test(a.texto)) bloquea('rsync a otra máquina no está permitido');
      this.comprobarEscritura(a.texto, destinoInofensivo);
    }
  }

  lee(verbo, argumentos) {
    if (INTERPRETES.has(verbo)) {
      const indice = argumentos.findIndex((a) => /^-[a-z]*c$/.test(a.texto));
      if (indice >= 0) {
        if (argumentos[indice + 1]?.dinamica) bloquea(`${verbo} -c con contenido calculado no se puede verificar`);
        if (argumentos[indice + 1]) this.analizar(argumentos[indice + 1].texto);
        return;
      }
    }
    const opcionCodigo = CON_CODIGO[verbo];
    if (opcionCodigo) {
      const indice = argumentos.findIndex((a) => a.texto === opcionCodigo);
      if (indice >= 0) {
        this.codigoEnLinea(argumentos[indice + 1]?.texto || '');
        return;
      }
    }
    let lista = this.posicionales(argumentos);
    if (CON_PATRON.has(verbo) && !argumentos.some((a) => /^(-e|-f|--regexp|--file)/.test(a.texto))) lista = lista.slice(1);
    for (const a of lista) {
      if (a.dinamica) {
        if (verbo === 'cd' || verbo === 'pushd') this.cwdConocido = false;
        continue;
      }
      this.comprobarLectura(a.texto);
      if (verbo === 'cd' || verbo === 'pushd') this.cwd = this.resolver(a.texto);
      if (INTERPRETES.has(verbo) || verbo === 'source' || verbo === '.') this.revisarScript(this.resolver(a.texto));
    }
  }

  // No puede seguir lo que el código haga al ejecutarse; solo mira las rutas absolutas que aparezcan en él.
  codigoEnLinea(codigo) {
    for (const m of codigo.matchAll(/['"](\/[^'"\s]*)['"]/g)) {
      // "/" suelto (separador) o algo cuya primera carpeta no existe, como "/admin/login" de una URL, no es una ruta del equipo.
      const primera = m[1].split('/')[1];
      if (!primera || !fs.existsSync(`/${primera}`)) continue;
      const ruta = this.resolver(m[1]);
      if (!this.lecturaPermitida(ruta) && !SALIDAS_INOFENSIVAS.has(ruta)) bloquea(`el código menciona ${ruta}, fuera de la raíz del proyecto`);
    }
  }

  git(argumentos) {
    for (let i = 0; i < argumentos.length; i += 1) {
      if (/^(-C|--git-dir|--work-tree)$/.test(argumentos[i].texto) && argumentos[i + 1]) {
        if (argumentos[i + 1].dinamica) bloquea('git -C con una ruta calculada no se puede verificar');
        this.comprobarLectura(argumentos[i + 1].texto);
      }
    }
  }

  descarga(verbo, argumentos) {
    const conRuta = verbo === 'curl'
      ? /^(-o|--output|-T|--upload-file|-c|--cookie-jar|-b|--cookie|-D|--dump-header|--output-dir)$/
      : /^(-O|--output-document|-P|--directory-prefix)$/;
    for (let i = 0; i < argumentos.length; i += 1) {
      const a = argumentos[i];
      if (conRuta.test(a.texto) && argumentos[i + 1]) {
        const siguiente = argumentos[i + 1];
        // Con un "=" literal, curl toma -b como cookie y no como archivo: no hay ruta que verificar.
        if (/^(-b|--cookie)$/.test(a.texto) && siguiente.texto.includes('=')) continue;
        this.comprobarDinamica(siguiente, verbo);
        if (/^(-T|--upload-file)$/.test(a.texto)) this.comprobarLectura(siguiente.texto);
        else if (/^(-b|--cookie)$/.test(a.texto) && !siguiente.texto.includes('=')) this.comprobarLectura(siguiente.texto);
        else if (!/^(-b|--cookie)$/.test(a.texto)) this.comprobarEscritura(siguiente.texto, true);
      }
      const adjunto = a.texto.match(/(?:^|=)@([^;]+)/);
      if (adjunto && !a.dinamica) this.comprobarLectura(adjunto[1]);
    }
  }

  find(argumentos) {
    let i = 0;
    while (i < argumentos.length && !/^[-(!]/.test(argumentos[i].texto)) {
      if (!argumentos[i].dinamica) this.comprobarLectura(argumentos[i].texto);
      i += 1;
    }
    for (; i < argumentos.length; i += 1) {
      const a = argumentos[i].texto;
      if (/^-(fprint|fprintf|fprint0|fls)$/.test(a)) bloquea(`find ${a} no se puede verificar`);
      if (/^-(exec|execdir|ok|okdir)$/.test(a)) {
        const resto = [];
        for (i += 1; i < argumentos.length && argumentos[i].texto !== ';' && argumentos[i].texto !== '+'; i += 1) {
          if (argumentos[i].texto !== '{}') resto.push(argumentos[i]);
        }
        this.orden({ palabras: resto, redirecciones: [] });
      }
    }
    if (argumentos.some((a) => a.dinamica) && argumentos.some((a) => /^-(delete|exec|execdir)$/.test(a.texto))) {
      bloquea('find con una ruta calculada no se puede verificar; escribe la ruta exacta');
    }
  }

  xargs(argumentos) {
    const verbo = argumentos.find((a) => !a.texto.startsWith('-'));
    if (verbo && (MODIFICAN.has(path.basename(verbo.texto)) || PROHIBIDOS.has(path.basename(verbo.texto)))) {
      bloquea(`xargs ${verbo.texto} no se puede verificar; escribe cada ruta exacta`);
    }
  }

  docker(argumentos) {
    const textos = argumentos.map((a) => a.texto);
    if (textos[0] === 'compose') return this.dockerCompose(argumentos.slice(1));
    const sub = textos[0] || '';
    const accion = textos[1] || '';
    if (sub.startsWith('-') && !/^(-v|--version|-h|--help)$/.test(sub)) {
      bloquea(`docker ${sub}: las opciones globales pueden cambiar de daemon o de configuración y no están permitidas`);
    }
    if (/^(swarm|stack|service|node|plugin|secret|config|login|logout|push|trust|manifest|commit|load|import)$/.test(sub)
      || (sub === 'context' && !/^(ls|show|inspect)$/.test(accion))
      || (sub === 'network' && /^(create|connect|disconnect)$/.test(accion))
      || (sub === 'volume' && accion === 'create')
      || (sub === 'image' && /^(push|load|import)$/.test(accion))) {
      bloquea(`docker ${sub}${accion && !accion.startsWith('-') ? ` ${accion}` : ''} no está permitido a los agentes`);
    }
    if (sub === 'tag' || (sub === 'image' && accion === 'tag')) {
      const nombres = argumentos.slice(sub === 'tag' ? 1 : 2).filter((a) => !a.texto.startsWith('-'));
      if (nombres.length) this.imagenPropia(nombres[nombres.length - 1]);
    }
    if (sub === 'save' || sub === 'export' || (/^(image|container)$/.test(sub) && /^(save|export)$/.test(accion))) {
      for (let i = 0; i < argumentos.length; i += 1) {
        const pegado = argumentos[i].texto.match(/^--output=(.+)$/);
        const destino = pegado ? { ...argumentos[i], texto: pegado[1] } : (/^(-o|--output)$/.test(argumentos[i].texto) ? argumentos[i + 1] : null);
        if (destino) { this.comprobarDinamica(destino, `docker ${sub}`); this.comprobarEscritura(destino.texto, true); }
      }
    }
    if (/^(rm|rmi)$/.test(sub)
      || (/^(system|image|volume|container|network|builder|buildx)$/.test(sub) && /^(prune|rm|remove)$/.test(accion))) {
      bloquea(`docker ${sub} ${accion} no está permitido a los agentes: usa docker compose sobre este entorno`);
    }
    const enContenedor = sub === 'container' ? accion : sub;
    const resto = argumentos.slice(sub === 'container' ? 2 : 1);
    if (/^(stop|kill|restart|pause|unpause|update|rename|start|exec|attach|wait)$/.test(enContenedor)) {
      return this.contenedoresPropios(enContenedor, resto);
    }
    if (enContenedor === 'run' || enContenedor === 'create') {
      this.nombrePropio(resto);
      this.pullNunca(resto);
      return this.dockerRun(resto);
    }
    if (sub === 'build' || ((sub === 'buildx' || sub === 'image') && accion === 'build')) {
      for (let i = 1; i < argumentos.length; i += 1) {
        const etiqueta = argumentos[i].texto.match(/^--tag=(.+)$/);
        if (etiqueta) this.imagenPropia({ ...argumentos[i], texto: etiqueta[1] });
        else if (/^(-t|--tag)$/.test(textos[i]) && argumentos[i + 1]) this.imagenPropia(argumentos[i + 1]);
        if (/^(-f|--file)$/.test(textos[i]) && argumentos[i + 1] && !argumentos[i + 1].dinamica) this.comprobarLectura(textos[i + 1]);
        if (!textos[i].startsWith('-') && i === argumentos.length - 1 && !argumentos[i].dinamica) this.comprobarLectura(textos[i]);
      }
    }
    if (sub === 'cp') {
      for (const a of argumentos.slice(1)) {
        if (!a.texto.startsWith('-') && !/^[^/]+:/.test(a.texto)) {
          this.comprobarDinamica(a, 'docker cp');
          this.comprobarEscritura(a.texto);
        }
      }
    }
    return undefined;
  }

  // Contenedores de este proyecto: los del compose de magents (<name>-<servicio>-<n> o <name>-<servicio>-run-<id>)
  // y los desechables de los agentes (<name>_tmp-<algo>). El "_" no puede aparecer en el nombre de otro proyecto de magents,
  // así que magents-cfw_tmp-x nunca es de magents-cfw-test.
  contenedores() {
    if (this.propios) return this.propios;
    let nombre = '';
    const servicios = [];
    try {
      const compose = fs.readFileSync(path.join(this.raiz, '.magents/entorno/compose.yml'), 'utf8');
      nombre = (compose.match(/^name:\s*["']?([a-z0-9][a-z0-9-]*)["']?\s*$/m) || [])[1] || '';
      const bloque = (compose.match(/^services:\s*\n((?:[ \t]+.*\n|\s*\n)*)/m) || [])[1] || '';
      for (const m of bloque.matchAll(/^ {2}([a-zA-Z0-9][a-zA-Z0-9_.-]*):\s*$/gm)) servicios.push(m[1]);
    } catch (e) {
      nombre = '';
    }
    if (!nombre) nombre = `magents-${path.basename(this.raiz).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')}`;
    const escapar = (t) => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const deCompose = servicios.length
      ? new RegExp(`^${escapar(nombre)}-(${servicios.map(escapar).join('|')})-(\\d+|run-[a-f0-9]+)$`)
      : null;
    const desechable = new RegExp(`^${escapar(nombre)}_tmp-[a-z0-9][a-z0-9.-]*$`);
    this.propios = { nombre, servicios, conCompose: servicios.length > 0, desechable, es: (t) => desechable.test(t) || Boolean(deCompose && deCompose.test(t)) };
    return this.propios;
  }

  // Una etiqueta de imagen solo puede ser de este proyecto: así no se pisa la imagen de otro.
  imagenPropia(a) {
    const { nombre, servicios } = this.contenedores();
    const escapar = (t) => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const de = servicios.length ? `|-(${servicios.map(escapar).join('|')})` : '';
    const valida = new RegExp(`^${escapar(nombre)}(_tmp-[a-z0-9][a-z0-9.-]*${de})(:[A-Za-z0-9_][A-Za-z0-9_.-]*)?$`);
    if (a.dinamica || !valida.test(a.texto)) {
      bloquea(`la imagen ${a.texto || 'calculada'} no es de este proyecto: usa ${nombre}-<servicio>:<etiqueta> o ${nombre}_tmp-<algo>, para no pisar imágenes de otros proyectos`);
    }
  }

  // Solo se actúa sobre contenedores de este proyecto, nombrados por su nombre completo (no por id).
  contenedoresPropios(accion, argumentos) {
    const propios = this.contenedores();
    const conValor = /^(-t|--time|-s|--signal|-e|--env|--env-file|-u|--user|-w|--workdir|--detach-keys|--condition|--cpus|--memory|-m|--restart|--cpu-shares|-c)$/;
    const objetivos = [];
    for (let i = 0; i < argumentos.length; i += 1) {
      const a = argumentos[i];
      if (conValor.test(a.texto)) { i += 1; continue; }
      if (a.texto.startsWith('-')) continue;
      objetivos.push(a);
      // exec y rename: tras el contenedor vienen el comando o el nombre nuevo.
      if (accion === 'exec' || accion === 'rename' || accion === 'attach') break;
    }
    if (accion === 'rename' && argumentos.length) objetivos.push(argumentos[argumentos.length - 1]);
    if (!objetivos.length) bloquea(`docker ${accion} sin contenedor no se puede verificar`);
    for (const a of objetivos) {
      if (a.dinamica || !propios.es(a.texto)) {
        bloquea(`docker ${accion} solo se permite sobre contenedores de este proyecto, por su nombre completo: los tuyos se llaman ${propios.nombre}_tmp-<algo> y los del entorno ${propios.nombre}-<servicio>-<n>; ${a.texto || 'una variable'} no lo es. Si es tuyo y está colgado, indícalo en tu informe para que lo pare el usuario`);
      }
    }
  }

  // Los contenedores que crea un agente llevan un nombre de este proyecto, para poder pararlos si se cuelgan.
  nombrePropio(argumentos) {
    const propios = this.contenedores();
    for (let i = 0; i < argumentos.length; i += 1) {
      const a = argumentos[i];
      const pegado = a.texto.match(/^--name=(.*)$/);
      const valor = pegado ? { ...a, texto: pegado[1] } : (a.texto === '--name' ? argumentos[i + 1] : null);
      if (valor) {
        if (!valor.dinamica && propios.desechable.test(valor.texto)) return;
        break;
      }
      if (!a.texto.startsWith('-') && !argumentos[i - 1]?.texto.startsWith('-')) break;
    }
    bloquea(`docker run necesita --name ${propios.nombre}_tmp-<algo> (minúsculas, números, puntos o guiones; por ejemplo ${propios.nombre}_tmp-lint), para poder pararlo si se cuelga`);
  }

  // Sin --pull never, docker run descarga la imagen si falta, sin que se vea en el comando.
  pullNunca(argumentos) {
    for (let i = 0; i < argumentos.length; i += 1) {
      const a = argumentos[i];
      if (!a.dinamica && (a.texto === '--pull=never' || (a.texto === '--pull' && argumentos[i + 1]?.texto === 'never' && !argumentos[i + 1].dinamica))) return;
      if (!a.texto.startsWith('-') && !argumentos[i - 1]?.texto.startsWith('-')) break;
    }
    bloquea('docker run necesita --pull never: usa una imagen que ya exista, como la del entorno, o descárgala antes con docker pull y decláralo');
  }

  dockerCompose(argumentos) {
    let i = 0;
    for (; i < argumentos.length; i += 1) {
      const a = argumentos[i];
      if (/^(-f|--file|--project-directory|--env-file)$/.test(a.texto)) {
        i += 1;
        if (argumentos[i] && !argumentos[i].dinamica) this.comprobarLectura(argumentos[i].texto);
      } else if (/^(-p|--project-name)$/.test(a.texto) || /^--project-name=/.test(a.texto)) {
        const valor = a.texto.includes('=') ? { ...a, texto: a.texto.split('=').slice(1).join('=') } : argumentos[i + 1];
        if (!a.texto.includes('=')) i += 1;
        const { nombre, conCompose } = this.contenedores();
        if (!valor || valor.dinamica || !conCompose || valor.texto !== nombre) {
          bloquea(`docker compose -p solo se permite con el proyecto de este entorno (${conCompose ? nombre : 'sin compose de magents'}); otro nombre actuaría sobre los contenedores de otro proyecto`);
        }
      } else if (/^(--profile|--ansi|--parallel|--progress)$/.test(a.texto)) {
        i += 1;
      } else if (!a.texto.startsWith('-')) {
        break;
      }
    }
    const sub = argumentos[i]?.texto;
    const resto = argumentos.slice(i + 1);
    if ((sub === 'down' || sub === 'rm') && resto.some((a) => /^(-v|--volumes|-[a-z]*v[a-z]*)$/.test(a.texto))) {
      bloquea('borrar los volúmenes de este entorno solo se hace con .magents/scripts/reiniciar-bd.sh');
    }
    if (sub === 'run') this.dockerRun(resto);
    if (sub === 'cp') {
      for (const a of resto) {
        if (!a.texto.startsWith('-') && !/^[^/]+:/.test(a.texto)) {
          this.comprobarDinamica(a, 'docker compose cp');
          this.comprobarEscritura(a.texto);
        }
      }
    }
  }

  dockerRun(argumentos) {
    for (let i = 0; i < argumentos.length; i += 1) {
      const a = argumentos[i];
      if (a.texto === '--privileged') bloquea('docker run --privileged no está permitido');
      let valor = null;
      const pegado = a.texto.match(/^(?:--volume|--mount)=(.*)$/);
      if (pegado) {
        valor = { ...a, texto: pegado[1] };
      } else if (/^(-v|--volume|--mount)$/.test(a.texto) && argumentos[i + 1]) {
        valor = argumentos[i + 1];
        i += 1;
      } else if (!a.texto.startsWith('-') && !argumentos[i - 1]?.texto.startsWith('-')) {
        break; // A partir de la imagen, los argumentos son del contenedor.
      }
      if (!valor) continue;
      if (valor.dinamica) bloquea('docker run con un montaje calculado no se puede verificar; usa $PWD o la ruta exacta');
      const fuente = valor.texto.includes('source=') || valor.texto.includes('src=')
        ? (valor.texto.match(/(?:source|src)=([^,]+)/) || [])[1]
        : valor.texto.split(':')[0];
      if (fuente && /[/.~]/.test(fuente[0])) {
        const ruta = this.resolver(fuente);
        if (!this.dentro(ruta)) bloquea(`docker run monta ${ruta}, fuera de la raíz del proyecto`);
      }
    }
  }
}

function leerAutorizadas(raiz) {
  let contenido = '';
  try {
    contenido = fs.readFileSync(path.join(raiz, ARCHIVO_RUTAS), 'utf8');
  } catch {
    return [];
  }
  return contenido.split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#') && path.isAbsolute(l)).map(real);
}

function revisarHerramienta(entrada, raiz) {
  const cwd = real(entrada.cwd || raiz);
  const analizador = new Analizador(raiz, cwd, leerAutorizadas(raiz));
  const datos = entrada.tool_input || {};
  const herramienta = entrada.tool_name || '';
  if (herramienta === 'Bash') {
    analizador.analizar(String(datos.command || ''));
  } else if (herramienta === 'Edit' || herramienta === 'Write' || herramienta === 'NotebookEdit') {
    analizador.comprobarEscritura(String(datos.file_path || datos.notebook_path || ''));
  } else if (herramienta === 'Glob' && path.isAbsolute(String(datos.pattern || ''))) {
    analizador.comprobarLectura(String(datos.pattern));
  } else {
    for (const [clave, valor] of Object.entries(datos)) {
      if (typeof valor === 'string' && /path|file|saveTo/i.test(clave) && valor !== '') {
        if (/^(http|https):/.test(valor)) continue;
        analizador.comprobarLectura(valor.replace(/^file:\/\//, ''));
      }
      if (clave === 'url' && typeof valor === 'string' && valor.startsWith('file://')) analizador.comprobarLectura(valor.slice(7));
    }
  }
}

function principal() {
  const crudo = fs.readFileSync(0, 'utf8');
  const entrada = JSON.parse(crudo);
  const raizTexto = process.env.CLAUDE_PROJECT_DIR;
  if (!raizTexto) throw new Error('falta CLAUDE_PROJECT_DIR');
  try {
    revisarHerramienta(entrada, real(raizTexto));
  } catch (error) {
    if (!(error instanceof Bloqueo)) throw error;
    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason: `magents: ${error.message}. No lo intentes por otra vía. Si de verdad hace falta, termina con VEREDICTO: BLOQUEADO indicando la ruta y el motivo, o si es un comando dentro del proyecto, reescríbelo con rutas exactas.`,
      },
    }));
  }
}

try {
  principal();
} catch (error) {
  // Ante un fallo del propio hook, se bloquea.
  console.error(`magents: no se ha podido verificar la orden: ${error.message}`);
  process.exit(2);
}
