FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
USER $APP_UID
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["Bugay.Service.Example.csproj", "."]
RUN dotnet restore "./Bugay.Service.Example.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "./Bugay.Service.Example.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./Bugay.Service.Example.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
USER root
RUN mkdir -p /certs && chmod 777 /certs
USER $APP_UID
ENTRYPOINT ["dotnet", "Bugay.Service.Example.dll"]
