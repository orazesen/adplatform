use actix_web::{get, App, HttpResponse, HttpServer, Responder};
use serde::Serialize;

#[derive(Serialize)]
struct Health {
    status: &'static str,
}

#[get("/healthz")]
async fn healthz() -> impl Responder {
    HttpResponse::Ok().json(Health { status: "ok" })
}

#[get("/")]
async fn index() -> impl Responder {
    println!("Handling request for /");
    HttpResponse::Ok().body("user-management ok")
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init();
    let addr = "0.0.0.0:8080";
    println!("Starting user-management on {}", addr);
    HttpServer::new(|| App::new().service(healthz).service(index))
        .bind(addr)?
        .run()
        .await
}
