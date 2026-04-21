import SwiftUI
// CAMBIO 1: Importar el framework de notificaciones
import UserNotifications

struct SideMenuView: View {
    @Environment(\.weatherTheme) private var theme
    @State private var isBusinessModeActive = false
    @State private var showBusinessToast = false
    @State private var showingGasolinaMeter = false
    @State private var showingContingencyCast = false
    var onBusinessToggle: (Bool) -> Void
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            Spacer()
            VStack(alignment: .leading, spacing: 0) {
                // ... (Cabecera del Menú - sin cambios)
                VStack(alignment: .leading) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Nombre de Usuario")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("usuario@email.com")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        MenuItem(icon: "person.fill", text: "Perfil")
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                isBusinessModeActive.toggle()
                            }
                            onBusinessToggle(isBusinessModeActive)
                            
                            // CAMBIO 3: Si el modo se acaba de ACTIVAR, enviar la notificación
                            if isBusinessModeActive {
                                scheduleBusinessNotification()
                            }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                showBusinessToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    showBusinessToast = false
                                }
                            }
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    if isBusinessModeActive {
                                        PulsingGlowView(color: .blue)
                                            .frame(width: 45, height: 45)
                                    }
                                    Image(systemName: "storefront")
                                        .font(.title3)
                                        .frame(width: 30)
                                }
                                
                                Text("Business")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(isBusinessModeActive ? .blue : .primary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isBusinessModeActive ? Color.blue.opacity(0.08) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isBusinessModeActive ? Color.blue.opacity(0.25) : Color.clear, lineWidth: 1)
                            )
                            .shadow(color: Color.blue.opacity(isBusinessModeActive ? 0.35 : 0), radius: isBusinessModeActive ? 12 : 0, x: 0, y: 6)
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .animation(.easeInOut(duration: 0.25), value: isBusinessModeActive)
                        }
                        
                        // GasolinaMeter - NUEVO hub
                        Button(action: {
                            showingGasolinaMeter = true
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.green.opacity(0.3), .teal.opacity(0.2)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "fuelpump.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.green)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("GasolinaMeter")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("Combustible · Estaciones · Multimodal")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("NUEVO")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .foregroundColor(theme.textTint)
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // ContingencyCast — pronóstico probabilístico contingencias
                        Button(action: {
                            showingContingencyCast = true
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.orange.opacity(0.3), .red.opacity(0.2)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "wind.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.orange)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ContingencyCast")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("Pronóstico contingencia 48-72h")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("AI")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .foregroundColor(theme.textTint)
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        MenuItem(icon: "gearshape.fill", text: "Configuración")
                        MenuItem(icon: "star.fill", text: "Favoritos")
                        MenuItem(icon: "questionmark.circle.fill", text: "Ayuda")
                    }
                    .padding()
                }
                
                Spacer()
                
                // ... (Pie del Menú - sin cambios)
                Divider()
                
                Button(action: {
                    print("Cerrar sesión presionado")
                }) {
                    HStack {
                        Image(systemName: "arrow.left.square.fill")
                            .font(.title2)
                        Text("Cerrar Sesión")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.red)
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // CAMBIO 2: Solicitar permiso para notificaciones cuando la vista aparece
        .onAppear(perform: requestNotificationPermission)
        .sheet(isPresented: $showingGasolinaMeter) {
            GasolinaMeterHubView()
        }
        .sheet(isPresented: $showingContingencyCast) {
            NavigationStack {
                ContingencyCastView()
            }
        }
        .overlay(
            VStack {
                if showBusinessToast {
                    BusinessToastView(message: "Modo Business activado")
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 40)
                        .padding(.horizontal, 16)
                }
                Spacer()
            }
        )
    }
    
    // --- FUNCIONES PARA NOTIFICACIONES ---

    /// Pide permiso al usuario para mostrar notificaciones.
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    /// Crea y programa una notificación local para que se muestre casi al instante.
    private func scheduleBusinessNotification() {
        let content = UNMutableNotificationContent()
        content.title = "New Business Alert 📍"
        content.body = "A new business is now available near your location."
        content.sound = UNNotificationSound.default

        // Configura el trigger para que la notificación aparezca 1 segundo después
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Crea la solicitud de notificación
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        // Añade la solicitud al centro de notificaciones
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
}

