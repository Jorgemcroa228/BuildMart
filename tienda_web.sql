-- =====================================================================
--  BASE DE DATOS: tienda_web
--  Venta de productos en la web
--  Motor: MySQL 8.0+ (InnoDB, utf8mb4)
--
--  Módulos:
--   1. Seguridad      -> roles, usuarios, recuperacion_password
--   2. Catálogo       -> categorias, productos (buscador FULLTEXT)
--   3. Carrito        -> carritos, carrito_items
--   4. Pedidos        -> pedidos, pedido_items (historial en el perfil)
--   5. Facturación    -> facturas, factura_items         (solo ADMIN)
--   6. Cotizaciones   -> cotizaciones, cotizacion_items,
--                        cotizacion_descargas             (solo ADMIN)
-- =====================================================================

DROP DATABASE IF EXISTS tienda_web;
CREATE DATABASE tienda_web
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE tienda_web;

-- =====================================================================
-- 1. SEGURIDAD
-- =====================================================================

-- Roles del sistema: ADMIN y USER
CREATE TABLE roles (
  id_rol      TINYINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  nombre      VARCHAR(20)  NOT NULL UNIQUE,
  descripcion VARCHAR(150)
) ENGINE=InnoDB;

-- Localidades (normalizado para no repetir texto en cada usuario)
CREATE TABLE localidades (
  id_localidad INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  nombre       VARCHAR(100) NOT NULL,
  ciudad       VARCHAR(100) NOT NULL,
  UNIQUE KEY uq_localidad (nombre, ciudad)
) ENGINE=InnoDB;

-- Usuarios: al registrarse se pide correo, teléfono, nombre y localidad
CREATE TABLE usuarios (
  id_usuario     INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  id_rol         TINYINT UNSIGNED NOT NULL DEFAULT 2,      -- 2 = USER
  id_localidad   INT UNSIGNED NOT NULL,
  nombre         VARCHAR(120) NOT NULL,
  correo         VARCHAR(150) NOT NULL UNIQUE,             -- login
  telefono       VARCHAR(20)  NOT NULL,
  password_hash  VARCHAR(255) NOT NULL,                    -- bcrypt/argon2, nunca texto plano
  activo         BOOLEAN      NOT NULL DEFAULT TRUE,
  ultimo_login   DATETIME     NULL,
  creado_en      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_usuario_rol       FOREIGN KEY (id_rol)       REFERENCES roles(id_rol),
  CONSTRAINT fk_usuario_localidad FOREIGN KEY (id_localidad) REFERENCES localidades(id_localidad)
) ENGINE=InnoDB;

-- Recuperar contraseña: solo para usuarios ya registrados.
-- Se guarda el HASH del token enviado al correo, con fecha de expiración.
CREATE TABLE recuperacion_password (
  id_recuperacion INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  id_usuario      INT UNSIGNED NOT NULL,
  token_hash      CHAR(64)     NOT NULL UNIQUE,            -- SHA-256 del token
  expira_en       DATETIME     NOT NULL,
  usado           BOOLEAN      NOT NULL DEFAULT FALSE,
  usado_en        DATETIME     NULL,
  ip_solicitud    VARCHAR(45)  NULL,
  creado_en       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_recup_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  INDEX idx_recup_usuario (id_usuario, usado)
) ENGINE=InnoDB;

-- =====================================================================
-- 2. CATÁLOGO DE PRODUCTOS
-- =====================================================================

CREATE TABLE categorias (
  id_categoria INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  nombre       VARCHAR(80) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Producto: nombre, imagen (ruta/URL del archivo cargado) y descripción.
-- Se agregan precio y stock porque los necesitan carrito, facturas y cotizaciones.
CREATE TABLE productos (
  id_producto    INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  id_categoria   INT UNSIGNED NULL,
  creado_por     INT UNSIGNED NOT NULL,                    -- ADMIN que lo creó
  nombre         VARCHAR(150) NOT NULL,
  descripcion    TEXT         NOT NULL,
  imagen_url     VARCHAR(500) NULL,                        -- ruta de la imagen cargada
  precio         DECIMAL(12,2) NOT NULL CHECK (precio >= 0),
  stock          INT UNSIGNED NOT NULL DEFAULT 0,
  activo         BOOLEAN      NOT NULL DEFAULT TRUE,
  creado_en      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria)
    REFERENCES categorias(id_categoria) ON DELETE SET NULL,
  CONSTRAINT fk_producto_admin FOREIGN KEY (creado_por)
    REFERENCES usuarios(id_usuario),
  -- Índice para el BUSCADOR de la web
  FULLTEXT INDEX ft_producto_busqueda (nombre, descripcion)
) ENGINE=InnoDB;

-- =====================================================================
-- 3. CARRITO DE COMPRAS
-- =====================================================================

-- Un carrito ABIERTO por usuario; al pagar pasa a CONVERTIDO (pedido).
CREATE TABLE carritos (
  id_carrito     INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  id_usuario     INT UNSIGNED NOT NULL,
  estado         ENUM('ABIERTO','CONVERTIDO','ABANDONADO') NOT NULL DEFAULT 'ABIERTO',
  creado_en      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- columna auxiliar: solo vale id_usuario cuando está ABIERTO -> 1 carrito abierto por usuario
  usuario_abierto INT UNSIGNED AS (IF(estado = 'ABIERTO', id_usuario, NULL)) STORED,
  UNIQUE KEY uq_carrito_abierto (usuario_abierto),
  -- (sin CASCADE: MySQL no lo permite sobre columnas usadas por una columna generada)
  CONSTRAINT fk_carrito_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuarios(id_usuario)
) ENGINE=InnoDB;

CREATE TABLE carrito_items (
  id_carrito   INT UNSIGNED NOT NULL,
  id_producto  INT UNSIGNED NOT NULL,
  cantidad     INT UNSIGNED NOT NULL DEFAULT 1 CHECK (cantidad > 0),
  agregado_en  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_carrito, id_producto),
  CONSTRAINT fk_citem_carrito  FOREIGN KEY (id_carrito)
    REFERENCES carritos(id_carrito) ON DELETE CASCADE,
  CONSTRAINT fk_citem_producto FOREIGN KEY (id_producto)
    REFERENCES productos(id_producto)
) ENGINE=InnoDB;

-- =====================================================================
-- 4. PEDIDOS (se muestran en el perfil del USER)
-- =====================================================================

CREATE TABLE pedidos (
  id_pedido        INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  id_usuario       INT UNSIGNED NOT NULL,
  id_carrito       INT UNSIGNED NULL UNIQUE,               -- carrito de origen
  estado           ENUM('PENDIENTE','PAGADO','ENVIADO','ENTREGADO','CANCELADO')
                   NOT NULL DEFAULT 'PENDIENTE',
  direccion_envio  VARCHAR(250) NOT NULL,
  total            DECIMAL(12,2) NOT NULL DEFAULT 0,
  creado_en        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_pedido_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
  CONSTRAINT fk_pedido_carrito FOREIGN KEY (id_carrito) REFERENCES carritos(id_carrito)
    ON DELETE SET NULL,
  INDEX idx_pedido_usuario (id_usuario, creado_en)
) ENGINE=InnoDB;

-- Se copia el precio al momento de la compra (si luego cambia el producto, el pedido no cambia)
CREATE TABLE pedido_items (
  id_pedido       INT UNSIGNED NOT NULL,
  id_producto     INT UNSIGNED NOT NULL,
  cantidad        INT UNSIGNED NOT NULL CHECK (cantidad > 0),
  precio_unitario DECIMAL(12,2) NOT NULL,
  subtotal        DECIMAL(12,2) AS (cantidad * precio_unitario) STORED,
  PRIMARY KEY (id_pedido, id_producto),
  CONSTRAINT fk_pitem_pedido   FOREIGN KEY (id_pedido)   REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
  CONSTRAINT fk_pitem_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB;

-- =====================================================================
-- 5. FACTURAS (las crea el ADMIN)
-- =====================================================================

CREATE TABLE facturas (
  id_factura     INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  numero         VARCHAR(20)  NOT NULL UNIQUE,             -- ej. FAC-000001
  id_admin       INT UNSIGNED NOT NULL,                    -- quien la emite
  id_cliente     INT UNSIGNED NOT NULL,                    -- usuario facturado
  id_pedido      INT UNSIGNED NULL UNIQUE,                 -- pedido facturado (opcional)
  fecha_emision  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subtotal       DECIMAL(12,2) NOT NULL DEFAULT 0,
  impuesto_pct   DECIMAL(5,2)  NOT NULL DEFAULT 19.00,     -- IVA
  impuesto       DECIMAL(12,2) NOT NULL DEFAULT 0,
  total          DECIMAL(12,2) NOT NULL DEFAULT 0,
  estado         ENUM('EMITIDA','PAGADA','ANULADA') NOT NULL DEFAULT 'EMITIDA',
  CONSTRAINT fk_factura_admin   FOREIGN KEY (id_admin)   REFERENCES usuarios(id_usuario),
  CONSTRAINT fk_factura_cliente FOREIGN KEY (id_cliente) REFERENCES usuarios(id_usuario),
  CONSTRAINT fk_factura_pedido  FOREIGN KEY (id_pedido)  REFERENCES pedidos(id_pedido)
) ENGINE=InnoDB;

CREATE TABLE factura_items (
  id_factura      INT UNSIGNED NOT NULL,
  id_producto     INT UNSIGNED NOT NULL,
  cantidad        INT UNSIGNED NOT NULL CHECK (cantidad > 0),
  precio_unitario DECIMAL(12,2) NOT NULL,
  subtotal        DECIMAL(12,2) AS (cantidad * precio_unitario) STORED,
  PRIMARY KEY (id_factura, id_producto),
  CONSTRAINT fk_fitem_factura  FOREIGN KEY (id_factura)  REFERENCES facturas(id_factura) ON DELETE CASCADE,
  CONSTRAINT fk_fitem_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB;

-- =====================================================================
-- 6. COTIZACIONES (las crea y descarga el ADMIN)
-- =====================================================================

CREATE TABLE cotizaciones (
  id_cotizacion   INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  numero          VARCHAR(20)  NOT NULL UNIQUE,            -- ej. COT-000001
  id_admin        INT UNSIGNED NOT NULL,
  id_cliente      INT UNSIGNED NULL,                       -- puede ser un usuario registrado...
  cliente_nombre  VARCHAR(120) NULL,                       -- ...o un prospecto externo
  cliente_correo  VARCHAR(150) NULL,
  fecha_emision   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  valida_hasta    DATE         NOT NULL,
  subtotal        DECIMAL(12,2) NOT NULL DEFAULT 0,
  impuesto_pct    DECIMAL(5,2)  NOT NULL DEFAULT 19.00,
  impuesto        DECIMAL(12,2) NOT NULL DEFAULT 0,
  total           DECIMAL(12,2) NOT NULL DEFAULT 0,
  estado          ENUM('BORRADOR','ENVIADA','ACEPTADA','RECHAZADA','VENCIDA')
                  NOT NULL DEFAULT 'BORRADOR',
  archivo_pdf_url VARCHAR(500) NULL,                       -- PDF generado para descargar
  notas           TEXT NULL,
  CONSTRAINT fk_cot_admin   FOREIGN KEY (id_admin)   REFERENCES usuarios(id_usuario),
  CONSTRAINT fk_cot_cliente FOREIGN KEY (id_cliente) REFERENCES usuarios(id_usuario),
  CONSTRAINT chk_cot_cliente CHECK (id_cliente IS NOT NULL OR cliente_nombre IS NOT NULL)
) ENGINE=InnoDB;

CREATE TABLE cotizacion_items (
  id_cotizacion   INT UNSIGNED NOT NULL,
  id_producto     INT UNSIGNED NOT NULL,
  cantidad        INT UNSIGNED NOT NULL CHECK (cantidad > 0),
  precio_unitario DECIMAL(12,2) NOT NULL,
  subtotal        DECIMAL(12,2) AS (cantidad * precio_unitario) STORED,
  PRIMARY KEY (id_cotizacion, id_producto),
  CONSTRAINT fk_coitem_cot      FOREIGN KEY (id_cotizacion) REFERENCES cotizaciones(id_cotizacion) ON DELETE CASCADE,
  CONSTRAINT fk_coitem_producto FOREIGN KEY (id_producto)   REFERENCES productos(id_producto)
) ENGINE=InnoDB;

-- Registro de cada descarga de cotización hecha por un ADMIN
CREATE TABLE cotizacion_descargas (
  id_descarga     INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  id_cotizacion   INT UNSIGNED NOT NULL,
  id_admin        INT UNSIGNED NOT NULL,
  descargado_en   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  formato         ENUM('PDF','XLSX') NOT NULL DEFAULT 'PDF',
  CONSTRAINT fk_desc_cot   FOREIGN KEY (id_cotizacion) REFERENCES cotizaciones(id_cotizacion) ON DELETE CASCADE,
  CONSTRAINT fk_desc_admin FOREIGN KEY (id_admin)      REFERENCES usuarios(id_usuario)
) ENGINE=InnoDB;

-- =====================================================================
-- REGLAS DE NEGOCIO (triggers): solo un ADMIN crea productos,
-- facturas, cotizaciones y descarga cotizaciones.
-- =====================================================================
DELIMITER $$

CREATE FUNCTION es_admin(p_id INT UNSIGNED) RETURNS BOOLEAN
READS SQL DATA
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM usuarios u JOIN roles r ON r.id_rol = u.id_rol
    WHERE u.id_usuario = p_id AND r.nombre = 'ADMIN' AND u.activo = TRUE
  );
END$$

CREATE TRIGGER trg_producto_solo_admin BEFORE INSERT ON productos
FOR EACH ROW BEGIN
  IF NOT es_admin(NEW.creado_por) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo un ADMIN puede crear productos';
  END IF;
END$$

CREATE TRIGGER trg_factura_solo_admin BEFORE INSERT ON facturas
FOR EACH ROW BEGIN
  IF NOT es_admin(NEW.id_admin) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo un ADMIN puede crear facturas';
  END IF;
END$$

CREATE TRIGGER trg_cotizacion_solo_admin BEFORE INSERT ON cotizaciones
FOR EACH ROW BEGIN
  IF NOT es_admin(NEW.id_admin) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo un ADMIN puede crear cotizaciones';
  END IF;
END$$

CREATE TRIGGER trg_descarga_solo_admin BEFORE INSERT ON cotizacion_descargas
FOR EACH ROW BEGIN
  IF NOT es_admin(NEW.id_admin) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo un ADMIN puede descargar cotizaciones';
  END IF;
END$$

-- Recalcular totales de la factura al agregar ítems
CREATE TRIGGER trg_fitem_total AFTER INSERT ON factura_items
FOR EACH ROW BEGIN
  UPDATE facturas f
     SET f.subtotal = (SELECT SUM(subtotal) FROM factura_items WHERE id_factura = NEW.id_factura),
         f.impuesto = ROUND(f.subtotal * f.impuesto_pct / 100, 2),
         f.total    = f.subtotal + f.impuesto
   WHERE f.id_factura = NEW.id_factura;
END$$

-- Recalcular totales de la cotización al agregar ítems
CREATE TRIGGER trg_coitem_total AFTER INSERT ON cotizacion_items
FOR EACH ROW BEGIN
  UPDATE cotizaciones c
     SET c.subtotal = (SELECT SUM(subtotal) FROM cotizacion_items WHERE id_cotizacion = NEW.id_cotizacion),
         c.impuesto = ROUND(c.subtotal * c.impuesto_pct / 100, 2),
         c.total    = c.subtotal + c.impuesto
   WHERE c.id_cotizacion = NEW.id_cotizacion;
END$$

-- Recalcular total del pedido al agregar ítems
CREATE TRIGGER trg_pitem_total AFTER INSERT ON pedido_items
FOR EACH ROW BEGIN
  UPDATE pedidos p
     SET p.total = (SELECT SUM(subtotal) FROM pedido_items WHERE id_pedido = NEW.id_pedido)
   WHERE p.id_pedido = NEW.id_pedido;
END$$

-- =====================================================================
-- PROCEDIMIENTOS
-- =====================================================================

-- Convierte el carrito abierto del usuario en un pedido
CREATE PROCEDURE sp_checkout(IN p_usuario INT UNSIGNED, IN p_direccion VARCHAR(250))
BEGIN
  DECLARE v_carrito INT UNSIGNED;
  DECLARE v_pedido  INT UNSIGNED;

  SELECT id_carrito INTO v_carrito
    FROM carritos WHERE id_usuario = p_usuario AND estado = 'ABIERTO';

  IF v_carrito IS NULL OR NOT EXISTS (SELECT 1 FROM carrito_items WHERE id_carrito = v_carrito) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El carrito está vacío';
  END IF;

  START TRANSACTION;
    INSERT INTO pedidos (id_usuario, id_carrito, direccion_envio)
    VALUES (p_usuario, v_carrito, p_direccion);
    SET v_pedido = LAST_INSERT_ID();

    INSERT INTO pedido_items (id_pedido, id_producto, cantidad, precio_unitario)
    SELECT v_pedido, ci.id_producto, ci.cantidad, p.precio
      FROM carrito_items ci JOIN productos p ON p.id_producto = ci.id_producto
     WHERE ci.id_carrito = v_carrito;

    UPDATE productos p JOIN carrito_items ci ON ci.id_producto = p.id_producto
       SET p.stock = p.stock - ci.cantidad
     WHERE ci.id_carrito = v_carrito;

    UPDATE carritos SET estado = 'CONVERTIDO' WHERE id_carrito = v_carrito;
  COMMIT;

  SELECT v_pedido AS id_pedido_creado;
END$$

-- Buscador de productos de la web
CREATE PROCEDURE sp_buscar_productos(IN p_texto VARCHAR(150))
BEGIN
  SELECT id_producto, nombre, descripcion, imagen_url, precio, stock,
         MATCH(nombre, descripcion) AGAINST (p_texto IN NATURAL LANGUAGE MODE) AS relevancia
    FROM productos
   WHERE activo = TRUE
     AND (MATCH(nombre, descripcion) AGAINST (p_texto IN NATURAL LANGUAGE MODE)
          OR nombre LIKE CONCAT('%', p_texto, '%'))
   ORDER BY relevancia DESC, nombre;
END$$

DELIMITER ;

-- =====================================================================
-- VISTAS
-- =====================================================================

-- "Mis pedidos" en el perfil del usuario
CREATE VIEW v_perfil_pedidos AS
SELECT u.id_usuario, u.nombre AS cliente, p.id_pedido, p.creado_en AS fecha,
       p.estado, p.total, COUNT(pi.id_producto) AS productos_distintos,
       SUM(pi.cantidad) AS unidades
  FROM pedidos p
  JOIN usuarios u       ON u.id_usuario = p.id_usuario
  LEFT JOIN pedido_items pi ON pi.id_pedido = p.id_pedido
 GROUP BY u.id_usuario, u.nombre, p.id_pedido, p.creado_en, p.estado, p.total;

-- Contenido del carrito abierto con totales
CREATE VIEW v_carrito_detalle AS
SELECT c.id_usuario, c.id_carrito, pr.id_producto, pr.nombre, pr.imagen_url,
       ci.cantidad, pr.precio, ci.cantidad * pr.precio AS subtotal
  FROM carritos c
  JOIN carrito_items ci ON ci.id_carrito = c.id_carrito
  JOIN productos pr     ON pr.id_producto = ci.id_producto
 WHERE c.estado = 'ABIERTO';

-- Datos que usa la web para generar el PDF descargable de una cotización
CREATE VIEW v_cotizacion_descarga AS
SELECT c.numero, c.fecha_emision, c.valida_hasta, c.estado,
       COALESCE(u.nombre, c.cliente_nombre) AS cliente,
       COALESCE(u.correo, c.cliente_correo) AS correo,
       pr.nombre AS producto, ci.cantidad, ci.precio_unitario, ci.subtotal,
       c.subtotal AS subtotal_cotizacion, c.impuesto, c.total,
       a.nombre AS elaborada_por
  FROM cotizaciones c
  JOIN cotizacion_items ci ON ci.id_cotizacion = c.id_cotizacion
  JOIN productos pr        ON pr.id_producto = ci.id_producto
  JOIN usuarios a          ON a.id_usuario = c.id_admin
  LEFT JOIN usuarios u     ON u.id_usuario = c.id_cliente;

-- =====================================================================
-- DATOS DE EJEMPLO
-- Contraseñas de PRUEBA (hash bcrypt, costo 12). La base solo guarda el hash;
-- la app compara con bcrypt.compare(passwordIngresada, password_hash).
--   admin@tienda.test -> Admin2026*
--   ana@correo.test   -> Ana2026*
--   luis@correo.test  -> Luis2026*
-- Cámbialas antes de usar la base en producción.
-- =====================================================================

INSERT INTO roles (id_rol, nombre, descripcion) VALUES
  (1, 'ADMIN', 'Administra productos, facturas y cotizaciones'),
  (2, 'USER',  'Cliente que compra en la tienda');

INSERT INTO localidades (nombre, ciudad) VALUES
  ('Chapinero', 'Bogotá'), ('Suba', 'Bogotá'), ('El Poblado', 'Medellín');

INSERT INTO usuarios (id_rol, id_localidad, nombre, correo, telefono, password_hash) VALUES
  (1, 1, 'Admin Tienda',  'admin@tienda.test',  '3000000001', '$2a$12$0nvFApQWhnCBH/V2FhXlx.JMdDhCS3l.zsf0LVAiBnjCxQ1UtE2M.'),
  (2, 2, 'Ana Gómez',     'ana@correo.test',    '3000000002', '$2a$12$dWCI2/I/tvTrrapHZxddL.kCQ2aWNsrb/if/RxO4kWn2zAmecixJC'),
  (2, 3, 'Luis Pérez',    'luis@correo.test',   '3000000003', '$2a$12$YtcXu3sPvwtnJoNy3RnPpuEHr0/LhqFhdywLCdRNFVsy7gNnCTSjW');

INSERT INTO categorias (nombre) VALUES ('Tecnología'), ('Hogar');

INSERT INTO productos (id_categoria, creado_por, nombre, descripcion, imagen_url, precio, stock) VALUES
  (1, 1, 'Audífonos Bluetooth', 'Audífonos inalámbricos con cancelación de ruido', '/uploads/productos/audifonos.jpg', 150000, 20),
  (1, 1, 'Mouse inalámbrico',   'Mouse ergonómico recargable',                   '/uploads/productos/mouse.jpg',      65000, 50),
  (2, 1, 'Lámpara LED',         'Lámpara de escritorio LED regulable',          '/uploads/productos/lampara.jpg',    89000, 15);

-- Ana agrega productos al carrito y hace el pedido
INSERT INTO carritos (id_usuario) VALUES (2);
INSERT INTO carrito_items (id_carrito, id_producto, cantidad) VALUES (1, 1, 1), (1, 2, 2);
CALL sp_checkout(2, 'Calle 145 # 90-10, Suba');

-- El ADMIN factura el pedido
INSERT INTO facturas (numero, id_admin, id_cliente, id_pedido) VALUES ('FAC-000001', 1, 2, 1);
INSERT INTO factura_items (id_factura, id_producto, cantidad, precio_unitario)
SELECT 1, id_producto, cantidad, precio_unitario FROM pedido_items WHERE id_pedido = 1;

-- El ADMIN crea una cotización para un prospecto y la descarga
INSERT INTO cotizaciones (numero, id_admin, cliente_nombre, cliente_correo, valida_hasta)
VALUES ('COT-000001', 1, 'Empresa XYZ', 'compras@xyz.test', CURDATE() + INTERVAL 15 DAY);
INSERT INTO cotizacion_items (id_cotizacion, id_producto, cantidad, precio_unitario)
VALUES (1, 3, 10, 85000), (1, 2, 10, 60000);
INSERT INTO cotizacion_descargas (id_cotizacion, id_admin) VALUES (1, 1);

-- =====================================================================
-- CONSULTAS DE PRUEBA
-- =====================================================================
-- CALL sp_buscar_productos('inalámbrico');
-- SELECT * FROM v_perfil_pedidos WHERE id_usuario = 2;
-- SELECT * FROM v_cotizacion_descarga WHERE numero = 'COT-000001';
-- INSERT INTO facturas (numero, id_admin, id_cliente) VALUES ('FAC-X', 2, 3);  -- falla: no es ADMIN
