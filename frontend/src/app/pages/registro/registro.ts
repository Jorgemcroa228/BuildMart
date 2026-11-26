import { Component, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import {
  AbstractControl,
  NonNullableFormBuilder,
  ReactiveFormsModule,
  ValidationErrors,
  Validators,
} from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { finalize } from 'rxjs';
import { AuthService, Localidad } from '../../services/auth.service';

/** Las dos contraseñas deben coincidir */
function passwordsIguales(grupo: AbstractControl): ValidationErrors | null {
  const pass = grupo.get('password')?.value;
  const conf = grupo.get('confirmar')?.value;
  return pass && conf && pass !== conf ? { noCoinciden: true } : null;
}

type Campo = 'nombre' | 'correo' | 'telefono' | 'id_localidad' | 'password' | 'confirmar';

@Component({
  selector: 'app-registro',
  imports: [ReactiveFormsModule, RouterLink],
  templateUrl: './registro.html',
  // Reutiliza los estilos del login para que ambas páginas se vean iguales
  styleUrls: ['../login/login.scss', './registro.scss'],
})
export class Registro {
  private readonly fb = inject(NonNullableFormBuilder);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  protected readonly form = this.fb.group(
    {
      nombre: ['', [Validators.required, Validators.minLength(3), Validators.maxLength(120)]],
      correo: ['', [Validators.required, Validators.email, Validators.maxLength(150)]],
      // Dígitos (7 a 15), con + opcional; se permiten espacios y guiones al escribir
      telefono: ['', [Validators.required, Validators.pattern(/^\+?[\d\s-]{7,20}$/)]],
      id_localidad: [0, [Validators.required, Validators.min(1)]],
      password: [
        '',
        [Validators.required, Validators.minLength(8), Validators.pattern(/^(?=.*[A-Za-z])(?=.*\d).+$/)],
      ],
      confirmar: ['', [Validators.required]],
    },
    { validators: passwordsIguales },
  );

  protected readonly localidades = signal<Localidad[]>([]);
  protected readonly errorLocalidades = signal(false);
  protected readonly cargando = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly verPassword = signal(false);

  constructor() {
    this.auth
      .localidades()
      .pipe(takeUntilDestroyed())
      .subscribe({
        next: (l) => this.localidades.set(l),
        error: () => this.errorLocalidades.set(true),
      });
  }

  protected invalido(campo: Campo): boolean {
    const c = this.form.controls[campo];
    const tocado = c.touched || c.dirty;
    if (campo === 'confirmar') return tocado && (c.invalid || this.form.hasError('noCoinciden'));
    return tocado && c.invalid;
  }

  protected enviar(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const { confirmar: _, ...datos } = this.form.getRawValue();
    this.error.set(null);
    this.cargando.set(true);

    this.auth
      .registro(datos)
      .pipe(finalize(() => this.cargando.set(false)))
      .subscribe({
        next: () => this.router.navigateByUrl('/'),
        error: (e: Error) => this.error.set(e.message),
      });
  }
}
