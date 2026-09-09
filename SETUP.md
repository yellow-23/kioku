# Kioku — pasos que faltan en Xcode

El código ya está listo (SwiftData + CloudKit). Faltan 2 cosas que solo se hacen desde la UI de Xcode:

1. Abre `kioku.xcodeproj`. Target `kioku` > **Signing & Capabilities**:
   - Confirma que tienes un **Team** seleccionado (tu Apple ID).
   - Si no aparece la capability **iCloud**: click en `+ Capability` > iCloud > marca **CloudKit**. Debe listar el contenedor `iCloud.tame.kioku` (ya está declarado en `kioku.entitlements`, Xcode debería reconocerlo o pedirte crearlo — acepta).
   - `+ Capability` > **Background Modes** > marca **Remote notifications** (para que el sync llegue con la app en segundo plano).
   - Repite lo mismo para el target de iOS si tienes uno separado; si es multiplataforma con un solo target ya quedó cubierto.

2. Corre en Mac (⌘R) logueado con tu Apple ID/iCloud, crea una nota. Luego corre en tu iPhone (mismo cable, mismo Apple ID) y verifica que la nota aparece.

Nota: con cuenta de desarrollador gratuita, la app instalada en el iPhone deja de abrir a los 7 días si no la vuelves a compilar desde Xcode.

## Qué se corrigió
- Habías creado el proyecto Xcode como **SwiftData**, no Core Data — el código se adaptó a SwiftData (`@Model`, `ModelConfiguration(cloudKitDatabase: .automatic)`) en vez de reescribir el proyecto.
- `Item.swift` (plantilla vacía) se reemplazó por `Note.swift` con los campos reales.
- `kioku.entitlements` tenía `icloud-container-identifiers` vacío — se agregó `iCloud.tame.kioku`.
- Se borraron los archivos sueltos que habían quedado duplicados un nivel arriba (fuera del proyecto Xcode real).
