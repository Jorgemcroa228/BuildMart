import { Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { finalize } from 'rxjs';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-login',
  imports: [ReactiveFormsModule, RouterLink],
  templateUrl: './login.html',
  styleUrl: './login.scss',
})
export class Login {
  private readonly fb = inject(NonNullableFormBuilder);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);

  protected readonly form = this.fb.group({
    correo: ['', [Validators.required, Validators.email, Validators.maxLength(150)]],
    password: ['', [Validators.required, Validators.minLength(8)]],
    recordar: [false],
  });

  protected readonly cargando = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly verPassword = signal(false);

  /** Muestra el error de un campo solo después de que el usuario lo tocó o intentó enviar */
  protected invalido(campo: 'correo' | 'password'): boolean {
    const c = this.form.controls[campo];
    return c.invalid && (c.touched || c.dirty);
  }

  protected enviar(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const { correo, password, recordar } = this.form.getRawValue();
    this.error.set(null);
    this.cargando.set(true);

    this.auth
      .login(correo, password, recordar)
      .pipe(finalize(() => this.cargando.set(false)))
      .subscribe({
        next: () => {
          // Si el usuario venía de una página protegida, se le devuelve allí
          const destino = this.route.snapshot.queryParamMap.get('redirect') ?? '/';
          this.router.navigateByUrl(destino);
        },
        error: (e: Error) => {
          this.error.set(e.message);
          this.form.controls.password.reset();
        },
      });
  }
}
