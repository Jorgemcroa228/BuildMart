import { Component, HostListener, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterLink } from '@angular/router';
import { filter, map } from 'rxjs';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-navbar',
  imports: [RouterLink],
  templateUrl: './navbar.html',
  styleUrl: './navbar.scss',
})
export class Navbar {
  /** Distancia de scroll (px) a partir de la cual aparece el NavBar */
  private readonly UMBRAL_SCROLL = 20;

  private readonly router = inject(Router);
  protected readonly auth = inject(AuthService);

  private readonly scrolled = signal(false);
  private readonly url = toSignal(
    this.router.events.pipe(
      filter((e) => e instanceof NavigationEnd),
      map((e) => e.urlAfterRedirects),
    ),
    { initialValue: this.router.url },
  );

  /** En el inicio aparece al hacer scroll (sobre el video); en las demás páginas siempre se ve */
  protected readonly visible = computed(() => this.scrolled() || this.url().split(/[?#]/)[0] !== '/');
  protected readonly cantidadCarrito = signal(0);

  @HostListener('window:scroll')
  onScroll(): void {
    this.scrolled.set(window.scrollY >= this.UMBRAL_SCROLL);
  }

  protected cerrarSesion(): void {
    this.auth.logout();
    this.router.navigateByUrl('/');
  }
}
