# Use the official .NET 9 runtime image as the base
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

# Use the .NET 9 SDK image to build the application
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy the solution and project files
COPY ["Sage200Microservice.API/Sage200Microservice.API.csproj", "Sage200Microservice.API/"]
COPY ["Sage200Microservice.Services/Sage200Microservice.Services.csproj", "Sage200Microservice.Services/"]
COPY ["Sage200Microservice.Data/Sage200Microservice.Data.csproj", "Sage200Microservice.Data/"]

# Restore dependencies
RUN dotnet restore "Sage200Microservice.API/Sage200Microservice.API.csproj"
COPY . .

# Build the application
WORKDIR "/src/Sage200Microservice.API"
RUN dotnet build "Sage200Microservice.API.csproj" -c Release -o /app/build

# Publish the application
FROM build AS publish
RUN dotnet publish "Sage200Microservice.API.csproj" -c Release -o /app/publish

# Final stage - copy the published application to the runtime image
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Sage200Microservice.API.dll"]