import {
  AfterViewInit,
  Component,
  DestroyRef,
  ElementRef,
  NgZone,
  inject,
  viewChildren,
} from '@angular/core';

interface Espacio {
  src: string;
  titulo: string;
  descripcion: string;
}

/**
 * Galería en espiral controlada por el scroll.
 * Las imágenes van una debajo de otra (separación = su propia altura + 40px).
 * Cada imagen cruza la pantalla girando de izquierda a derecha sobre una espiral,
 * y al llegar al centro aparece su texto: la 1ª a la izquierda, la 2ª a la derecha, etc.
 */
@Component({
  selector: 'app-galeria-espiral',
  templateUrl: './galeria-espiral.html',
  styleUrl: './galeria-espiral.scss',
})
export class GaleriaEspiral implements AfterViewInit {
  /** Giro máximo (grados) al entrar por la izquierda / salir por la derecha */
  private readonly GIRO_MAX = 55;

  protected readonly espacios: Espacio[] = [
    {
      src: 'galeria/banos.png',
      titulo: 'Tu baño',
      descripcion:
        'Regaderas, monocontroles, lavamanos y toalleros para crear un baño moderno, funcional y hecho para durar.',
    },
    {
      src: 'galeria/lavanderia.png',
      titulo: 'Tu lavandería',
      descripcion:
        'Lavaderos, grifería y desagües resistentes para que tu zona de ropas trabaje tan duro como tú.',
    },
    {
      src: 'galeria/cocina.png',
      titulo: 'Tu cocina',
      descripcion:
        'Monocontroles, lavaplatos, teleduchas y rejillas con acabados que unen diseño y uso diario.',
    },
    {
      src: 'galeria/tuberia.png',
      titulo: 'Redes hidráulicas',
      descripcion:
        'Tubería, conexiones y accesorios para instalaciones de agua seguras, desde la obra hasta el último punto.',
    },
  ];

  private readonly filas = viewChildren<ElementRef<HTMLElement>>('fila');
  private readonly zone = inject(NgZone);
  private readonly destroyRef = inject(DestroyRef);

  private frame = 0;

  ngAfterViewInit(): void {
    // Movimiento reducido: imágenes quietas y textos siempre visibles (ver SCSS)
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) {
      this.filas().forEach((f) => f.nativeElement.classList.add('fila--visible'));
      return;
    }

    // El scroll se procesa fuera de Angular: solo se escriben transform/opacity y una clase
    this.zone.runOutsideAngular(() => {
      const programar = () => {
        if (!this.frame) this.frame = requestAnimationFrame(() => this.pintar());
      };
      window.addEventListener('scroll', programar, { passive: true });
      window.addEventListener('resize', programar);
      this.pintar();

      this.destroyRef.onDestroy(() => {
        window.removeEventListener('scroll', programar);
        window.removeEventListener('resize', programar);
        cancelAnimationFrame(this.frame);
      });
    });
  }

  private pintar(): void {
    this.frame = 0;
    const alto = window.innerHeight;
    const centroPantalla = alto / 2;
    const radio = Math.min(360, window.innerWidth * 0.3);

    for (const ref of this.filas()) {
      const fila = ref.nativeElement;
      const tarjeta = fila.querySelector<HTMLElement>('.espiral__tarjeta');
      if (!tarjeta) continue;

      // p = 1 entrando por abajo · 0 en el centro · -1 saliendo por arriba
      const r = fila.getBoundingClientRect();
      const centro = r.top + r.height / 2;
      const p = Math.max(-1, Math.min(1, (centro - centroPantalla) / (centroPantalla + r.height / 2)));

      // Recorrido en espiral: entra por la izquierda, pasa al frente y sale por la derecha girando
      const angulo = -p * this.GIRO_MAX;
      const rad = (angulo * Math.PI) / 180;
      const x = Math.sin(rad) * radio;
      const z = (Math.cos(rad) - 1) * radio;

      tarjeta.style.transform = `translate3d(${x}px, 0, ${z}px) rotateY(${angulo}deg)`;
      tarjeta.style.opacity = (1 - Math.abs(p) * 0.55).toFixed(3);

      // El texto aparece cuando la imagen está cerca del centro
      fila.classList.toggle('fila--visible', Math.abs(p) < 0.4);
    }
  }
}
