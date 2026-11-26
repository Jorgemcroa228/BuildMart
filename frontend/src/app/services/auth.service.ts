import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { Observable, catchError, tap, throwError } from 'rxjs';

/** URL base de la API (backend aún por construir) */
export const API_URL = '/api';

export type Rol = 'ADMIN' | 'USER';

export interface Usuario {
  id_usuario: number;
  nombre: string;
  correo: string;
  rol: Rol;
}

export interface LoginRespuesta {
  token: string;
  usuario: Usuario;
}

export interface Localidad {
  id_localidad: number;
  nombre: string;
  ciudad: string;
}

export interface RegistroDatos {
  nombre: string;
  correo: string;
  telefono: string;
  id_localidad: number;
  password: string;
}

const CLAVE_SESION = 'bm_sesion';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);

  private readonly sesion = signal<LoginRespuesta | null>(this.leerSesion());

  readonly usuario = computed(() => this.sesion()?.usuario ?? null);
  readonly autenticado = computed(() => this.sesion() !== null);
  readonly esAdmin = computed(() => this.usuario()?.rol === 'ADMIN');

  get token(): string | null {
    return this.sesion()?.token ?? null;
  }

  /**
   * Inicia sesión con correo y contraseña.
   * @param recordar si es true la sesión se guarda en localStorage (persiste al cerrar el navegador);
   *                 si es false, en sessionStorage (se borra al cerrar la pestaña).
   */
  login(correo: string, password: string, recordar: boolean): Observable<LoginRespuesta> {
    return this.http
      .post<LoginRespuesta>(`${API_URL}/auth/login`, { correo: correo.trim().toLowerCase(), password })
      .pipe(
        tap((resp) => {
          this.guardarSesion(resp, recordar);
          this.sesion.set(resp);
        }),
        catchError((err: HttpErrorResponse) => throwError(() => new Error(this.mensajeError(err)))),
      );
  }

  /** Crea la cuenta (rol USER) y deja la sesión iniciada con la respuesta del servidor */
  registro(datos: RegistroDatos): Observable<LoginRespuesta> {
    const cuerpo: RegistroDatos = {
      ...datos,
      nombre: datos.nombre.trim().replace(/\s+/g, ' '),
      correo: datos.correo.trim().toLowerCase(),
      telefono: datos.telefono.replace(/[\s-]/g, ''),
    };
    return this.http.post<LoginRespuesta>(`${API_URL}/auth/registro`, cuerpo).pipe(
      tap((resp) => {
        this.guardarSesion(resp, false);
        this.sesion.set(resp);
      }),
      catchError((err: HttpErrorResponse) => throwError(() => new Error(this.mensajeErrorRegistro(err)))),
    );
  }

  /** Lista de localidades para el formulario de registro */
  localidades(): Observable<Localidad[]> {
    return this.http.get<Localidad[]>(`${API_URL}/localidades`);
  }

  logout(): void {
    this.almacenar(localStorage, null);
    this.almacenar(sessionStorage, null);
    this.sesion.set(null);
  }

  private mensajeError(err: HttpErrorResponse): string {
    switch (err.status) {
      case 0:
        return 'No se pudo conectar con el servidor. Intenta de nuevo más tarde.';
      case 400:
      case 401:
        return 'Correo o contraseña incorrectos.';
      case 403:
        return 'Tu cuenta está desactivada. Contacta con soporte.';
      case 429:
        return 'Demasiados intentos. Espera unos minutos antes de volver a intentar.';
      default:
        return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }

  private mensajeErrorRegistro(err: HttpErrorResponse): string {
    switch (err.status) {
      case 0:
        return 'No se pudo conectar con el servidor. Intenta de nuevo más tarde.';
      case 400:
        return 'Revisa los datos del formulario.';
      case 409:
        return 'Ya existe una cuenta con ese correo.';
      case 429:
        return 'Demasiados intentos. Espera unos minutos antes de volver a intentar.';
      default:
        return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }

  private guardarSesion(resp: LoginRespuesta, recordar: boolean): void {
    this.almacenar(recordar ? localStorage : sessionStorage, resp);
    this.almacenar(recordar ? sessionStorage : localStorage, null);
  }

  private almacenar(storage: Storage, valor: LoginRespuesta | null): void {
    try {
      if (valor) storage.setItem(CLAVE_SESION, JSON.stringify(valor));
      else storage.removeItem(CLAVE_SESION);
    } catch {
      /* almacenamiento no disponible (modo privado, etc.) */
    }
  }

  private leerSesion(): LoginRespuesta | null {
    for (const storage of [localStorage, sessionStorage]) {
      try {
        const raw = storage.getItem(CLAVE_SESION);
        if (raw) return JSON.parse(raw) as LoginRespuesta;
      } catch {
        /* ignorar datos corruptos o storage bloqueado */
      }
    }
    return null;
  }
}
