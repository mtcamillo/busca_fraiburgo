# Busca Fraiburgo

Aplicativo em Flutter para reunir e facilitar o acesso a lojas, serviços e pontos de interesse de Fraiburgo-SC.  
O app utiliza **Supabase** como backend (banco de dados, autenticação e storage) e **Google Maps** para exibição de localização das lojas.


---


## Funcionalidades atuais

- **Cadastro/Login de usuários**
  - Autenticação com Supabase Auth.
  - Cadastro com nome, telefone e e-mail.

- **Cadastro de lojas**
  - Campos: WhatsApp, Instagram, horários de funcionamento, categoria, descrição e nome da loja.
  - Suporte a geolocalização (latitude/longitude) para mostrar no mapa.

- **Categorias**
  - Listagem dinâmica a partir do banco de dados (ex: Vestuário, Tecnologia, Restaurantes, Pets, etc).
  - Ícones personalizados por categoria.

- **Lojas**
  - Aba dedicada mostrando todas as lojas, com **filtros** (por categoria, abertas agora, verificadas, etc).

- **Mapa**
  - Integração com Google Maps.
  - Exibição da posição das lojas cadastradas.
  - Chaves de API gerenciadas por variáveis de ambiente.

- **Favoritos**
  - Usuário pode favoritar/desfavoritar lojas.
  - Favoritos ficam vinculados ao usuário logado.

- **Perfil**
  - Exibição dos dados do usuário autenticado.
  - Possibilidade futura de editar perfil e gerenciar lojas.


---


## Tecnologias

- **Flutter 3.x** (Material 3 / Dart)
- **Supabase**
  - Postgres + RLS
  - Supabase Auth
  - Supabase Storage
- **Google Maps SDK**
- **Provider** para gerenciamento de estado
- **Flutter DotEnv** para variáveis de ambiente


---


## Como rodar o projeto

### Pré-requisitos
- [Flutter](https://docs.flutter.dev/get-started/install) instalado e configurado.
- Emulador Android/iOS ou dispositivo físico conectado.
- Conta no [Supabase](https://supabase.com/).
- Chave de API do [Google Maps](https://console.cloud.google.com/).

### Configuração inicial

1. Clone o repositório:
 ```bash
 git clone https://github.com/SEU_USUARIO/busca_fraiburgo.git
 cd busca_fraiburgo
```
   
2. Instale as dependências:
  ```bash
  flutter pub get
  ```



3. Configure o arquivo .env na raiz do projeto:
  ```bash
  SUPABASE_URL=https://SEU-PROJETO.supabase.co
  SUPABASE_ANON_KEY=eyJhbGciOi...
  GOOGLE_MAPS_KEY=AIzaSy...
   ```
    

4. Configure o Google Maps no Android:

  Arquivo: android/app/src/main/AndroidManifest.xml
  
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="${GOOGLE_MAPS_KEY}"/>


Rode o projeto:
```bash
flutter run -d emulator-5554
```


---


## Estrutura do projeto (simplificada)
```bash
lib/
 ├─ app.dart              # Estrutura principal com bottom navigation
 ├─ main.dart             # Inicialização do Supabase e App
 ├─ services/
 │   └─ supabase_service.dart
 ├─ providers/
 │   └─ auth_provider.dart
 ├─ ui/
 │   ├─ screens/
 │   │   ├─ home_screen.dart
 │   │   ├─ categories_screen.dart
 │   │   ├─ all_stores_screen.dart
 │   │   ├─ map_screen.dart
 │   │   ├─ favorites_screen.dart
 │   │   ├─ profile_screen.dart
 │   │   └─ store_detail_screen.dart
 │   └─ widgets/
 │       └─ category_tile.dart
 └─ utils/
     └─ hours.dart        # Funções para cálculo de horários abertos/fechados
```


---



## Próximos passos planejados

 - Upload de imagens das lojas para Supabase Storage.
 - Busca avançada (Full Text Search) com ordenação por relevância.
 - Tela de edição de perfil do usuário.
 - Melhorar performance do mapa com clusterização de marcadores.
 - Deploy em loja (Google Play / App Store).
